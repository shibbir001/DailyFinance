// Controllers/AuthController.swift
import Foundation
internal import CoreData
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Combine

class AuthController: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = AuthController()

    // MARK: - Published Properties
    @Published var isLoggedIn:        Bool   = false
    @Published var isLoading:         Bool   = false
    @Published var isCheckingSession: Bool   = true  // ✅ starts true
    @Published var errorMessage:      String = ""
    @Published var currentUserId:     String = ""
    @Published var userName:          String = ""
    @Published var userEmail:         String = ""

    private let supabase = SupabaseService.shared.client
    private var currentNonce: String = ""

    // MARK: - Init
    private override init() {
        super.init()
        checkSession()
    }

    // MARK: - Check Existing Session
    func checkSession() {
        Task {
            // ✅ Step 1: Check fresh install flag
            let installedKey = "app_has_launched_v2"
            let isInstalled  = UserDefaults.standard
                .bool(forKey: installedKey)

            if !isInstalled {
                print("🆕 Fresh install — showing login")
                await MainActor.run { self.isLoggedIn = false }
                return
            }

            // ✅ Step 2: Try local session FIRST (fast, no network)
            // This keeps user logged in when app reopens
            do {
                let session = try await supabase.auth.session

                // ✅ Valid local session found — log in immediately
                let userId = session.user.id.uuidString
                let email  = session.user.email ?? ""

                // ✅ Set userId FIRST before any operations
                CoreDataManager.shared.currentUserId = userId
                UserPreferences.shared.loadForUser(userId)

                await MainActor.run {
                    self.currentUserId = userId
                    self.userEmail     = email
                    self.isLoggedIn    = true
                }

                print("✅ Session restored: \(userId.prefix(8))")
                print("   CoreData userId: \(CoreDataManager.shared.currentUserId.prefix(8))")

                // ✅ Reload data for this user
                await reloadAfterLogin(
                    userId: userId,
                    email:  email,
                    name:   ""
                )

                // ✅ Done checking
                await MainActor.run {
                    self.isCheckingSession = false
                    // ✅ Signal dashboard to start polling for iCloud txs
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SessionRestored"),
                        object: nil
                    )
                }

                // ✅ Step 4: Refresh token in BACKGROUND
                // Non-blocking — user already sees dashboard
                Task {
                    do {
                        try await supabase.auth.refreshSession()
                        print("✅ Token refreshed in background")
                    } catch {
                        // Token refresh failed but user is
                        // still logged in locally
                        // They will be asked to login again
                        // only when token truly expires
                        print("⚠️ Background refresh failed: \(error)")
                    }
                }

            } catch {
                // ✅ No local session — show login
                print("ℹ️ No session found — showing login")
                await MainActor.run {
                    self.isLoggedIn        = false
                    self.currentUserId     = ""
                    self.isCheckingSession = false  // ✅ done
                    CoreDataManager.shared.currentUserId = ""
                }
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: APPLE SIGN IN
    // MARK: ─────────────────────────────────────

    func startAppleSignIn() {
        let nonce    = randomNonceString()
        currentNonce = nonce

        let request  = ASAuthorizationAppleIDProvider()
            .createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce           = sha256(nonce)

        let controller = ASAuthorizationController(
            authorizationRequests: [request]
        )
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: ─────────────────────────────────────
    // MARK: GOOGLE SIGN IN
    // MARK: ─────────────────────────────────────

    func startGoogleSignIn() async {
        await MainActor.run {
            isLoading    = true
            errorMessage = ""
        }

        do {
            guard let windowScene = await UIApplication
                .shared.connectedScenes
                .first as? UIWindowScene,
                let rootVC = await windowScene
                    .windows.first?.rootViewController
            else {
                await MainActor.run {
                    self.errorMessage = "Cannot find view controller"
                    self.isLoading    = false
                }
                return
            }

            let result = try await GIDSignIn.sharedInstance
                .signIn(withPresenting: rootVC)

            guard let idToken = result.user
                .idToken?.tokenString
            else {
                await MainActor.run {
                    self.errorMessage = "No ID token from Google"
                    self.isLoading    = false
                }
                return
            }

            let accessToken = result.user
                .accessToken.tokenString
            let googleName  = result.user.profile?.name ?? ""
            let googleEmail = result.user.profile?.email ?? ""

            let session = try await supabase.auth
                .signInWithIdToken(
                    credentials: .init(
                        provider:    .google,
                        idToken:     idToken,
                        accessToken: accessToken
                    )
                )

            await MainActor.run {
                self.currentUserId = session.user.id.uuidString
                self.userEmail     = googleEmail
                self.userName      = googleName
                self.isLoading     = false
                self.isLoggedIn    = true
                CoreDataManager.shared.currentUserId =
                    session.user.id.uuidString
            }

            await reloadAfterLogin(
                userId: session.user.id.uuidString,
                email:  googleEmail,
                name:   googleName
            )

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading    = false
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: SIGN OUT
    // MARK: ─────────────────────────────────────

    func signOut() async {
        print("🚪 Signing out — clearing all data...")

        // ✅ Step 1: Sign out from providers
        GIDSignIn.sharedInstance.signOut()

        // ✅ Step 2: Sign out from Supabase
        // Even if this fails, we clear local data
        try? await supabase.auth.signOut()

        // ✅ Step 3: Nuclear clear Core Data
        let coreData = CoreDataManager.shared
        coreData.clearAllLocalData()
        coreData.currentUserId = ""

        // ✅ Step 4: Clear UserPreferences
        UserDefaults.standard.removeObject(
            forKey: "userCurrency"
        )
        UserDefaults.standard.removeObject(
            forKey: "userName_\(currentUserId)"
        )

        // ✅ Step 5: Reset UserPreferences
        await MainActor.run {
            UserPreferences.shared.currency = "USD"
            UserPreferences.shared.userName = ""
        }

        // ✅ Step 6: Update auth state
        await MainActor.run {
            self.isLoggedIn    = false
            self.currentUserId = ""
            self.userName      = ""
            self.userEmail     = ""
            self.errorMessage  = ""
        }

        // ✅ Verify clear worked
        let summaryCount = coreData.fetchAllSummaries().count
        print("✅ Sign out complete")
        print("   Remaining summaries: \(summaryCount)")
    }

    // MARK: ─────────────────────────────────────
    // MARK: RELOAD AFTER LOGIN
    // ─────────────────────────────────────────
    func reloadAfterLogin(
        userId: String,
        email:  String,
        name:   String
    ) async {
        let coreData = CoreDataManager.shared

        // ✅ Step 1: Check if this is a DIFFERENT user
        // than what's currently in Core Data
        let previousUserId = coreData.currentUserId
        let isUserSwitch   = !previousUserId.isEmpty
            && previousUserId != userId

        if isUserSwitch {
            // ✅ Different user logged in!
            // Clear ALL local data to prevent data leak
            print("🔄 User switched: \(previousUserId.prefix(8)) → \(userId.prefix(8))")
            print("🗑️ Clearing local data for clean state...")
            coreData.clearAllLocalData()
        }

        // ✅ Step 2: Set new userId
        coreData.currentUserId = userId

        // ✅ Step 3: Refresh categories if outdated
        let expenseCount = coreData
            .fetchCategories(type: "expense").count
        if !coreData.categoriesExist() {
            coreData.addDefaultCategories()
            print("✅ Default categories created")
        } else if expenseCount < 20 {
            // Old version had 10, new has 35+
            print("🔄 Refreshing old categories (\(expenseCount) → 35+)")
            coreData.refreshDefaultCategories()
        } else {
            // ✅ Deduplicate on every login
            coreData.deduplicateCategories()
            print("✅ Categories OK (\(expenseCount) expense)")
        }

        // ✅ Step 4: Load user preferences
        await MainActor.run {
            UserPreferences.shared.loadForUser(userId)
        }

        // ✅ Step 5: On fresh install, wait for iCloud
        // App was deleted → Core Data empty
        // iCloud needs time to push transactions back
        let allTxReq: NSFetchRequest<TransactionEntity>
            = TransactionEntity.fetchRequest()
        let existingTxCount = (try? coreData.context
            .fetch(allTxReq))?.count ?? 0
        let existingSummaryCount = coreData.fetchAllSummaries().count

        if CoreDataManager.iCloudEnabledAtLaunch
            && existingTxCount == 0
            && existingSummaryCount == 0 {
            print("⏳ Fresh install — waiting for iCloud to push data...")
            for attempt in 1...8 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let txCount = (try? coreData.context
                    .fetch(allTxReq))?.count ?? 0
                let sumCount = coreData.fetchAllSummaries().count
                print("   iCloud attempt \(attempt): \(txCount) txs, \(sumCount) summaries")
                if txCount > 0 || sumCount > 0 { break }
            }
        }

        let localCount = coreData.fetchAllSummaries().count
        print("📊 Local summaries: \(localCount)")

        // ✅ Step 6: Always sync from Supabase
        if NetworkMonitor.shared.isConnected {
            print("📥 Restoring from Supabase for: \(userId.prefix(8))...")
            await SyncService.shared.restoreAllData()
        } else {
            print("📵 Offline — using \(localCount) local records")
            await MainActor.run {
                TransactionController.shared.loadTodayData()
                TransactionController.shared.loadCategories()
                HistoryController.shared.loadMonthData()
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: CREATE PROFILE IF NEEDED
    // ─────────────────────────────────────────
    private func createProfileIfNeeded(
        userId: String,
        email:  String,
        name:   String
    ) async {

        do {
            // Check if profile already exists
            let response = try await supabase
                .from("profiles")
                .select("id")
                .eq("id", value: userId)
                .execute()

            // Parse response to check if empty
            let data   = response.data
            let str    = String(data: data, encoding: .utf8) ?? "[]"
            let exists = str != "[]" && str != "[ ]" && str.count > 5

            if exists {
                print("✅ Profile already exists")
                return
            }

            // ✅ Profile doesn't exist — create it
            struct ProfileInsert: Encodable {
                let id:        String
                let full_name: String
                let currency:  String
                let email:     String
            }

            let profile = ProfileInsert(
                id:        userId,
                full_name: name.isEmpty ? email : name,
                currency:  "USD",
                email:     email
            )

            try await supabase
                .from("profiles")
                .insert(profile)
                .execute()

            print("✅ Profile created for: \(email)")

        } catch {
            print("⚠️ Profile check/create error: \(error)")
            // Non-fatal — app continues working
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: APPLE SIGN IN HELPERS
    // ─────────────────────────────────────────
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode   = SecRandomCopyBytes(
            kSecRandomDefault,
            randomBytes.count,
            &randomBytes
        )
        precondition(errorCode == errSecSuccess)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        })
    }

    private func sha256(_ input: String) -> String {
        let inputData  = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
    }
}

// MARK: ─────────────────────────────────────────
// MARK: APPLE SIGN IN DELEGATE
// ─────────────────────────────────────────────
extension AuthController: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential
            as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken   = String(data: tokenData, encoding: .utf8)
        else {
            self.errorMessage = "Apple Sign In failed"
            return
        }

        let firstName = credential.fullName?.givenName  ?? ""
        let lastName  = credential.fullName?.familyName ?? ""
        let fullName  = "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespaces)
        let appleEmail = credential.email ?? ""

        Task {
            await MainActor.run { self.isLoading = true }

            do {
                let session = try await supabase.auth
                    .signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken:  idToken,
                            nonce:    currentNonce
                        )
                    )

                let finalEmail = appleEmail.isEmpty
                    ? (session.user.email ?? "")
                    : appleEmail

                let finalName = fullName.isEmpty
                    ? finalEmail
                    : fullName

                await MainActor.run {
                    self.currentUserId = session.user.id.uuidString
                    self.userEmail     = finalEmail
                    self.userName      = finalName
                    self.isLoading     = false
                    self.isLoggedIn    = true
                    CoreDataManager.shared.currentUserId =
                        session.user.id.uuidString
                }

                await reloadAfterLogin(
                    userId: session.user.id.uuidString,
                    email:  finalEmail,
                    name:   finalName
                )

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading    = false
                }
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as NSError).code == 1001 {
            print("ℹ️ User cancelled Apple Sign In")
            return
        }
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isLoading    = false
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: APPLE PRESENTATION CONTEXT
// ─────────────────────────────────────────────
extension AuthController:
    ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared
            .connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first
        else { return UIWindow() }
        return window
    }
}
