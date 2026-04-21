// Controllers/AuthController.swift
import Foundation
internal import CoreData
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Combine
import UIKit

class AuthController: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = AuthController()

    // MARK: - Published Properties
    @Published var isLoggedIn:           Bool   = false
    @Published var isLoading:            Bool   = false
    @Published var isCheckingSession:    Bool   = true
    @Published var errorMessage:         String = ""
    @Published var currentUserId:        String = ""
    @Published var userName:             String = ""
    @Published var userEmail:            String = ""
    @Published var isSyncingFromICloud:  Bool   = false
    @Published var avatarURL:            URL?   = nil  // ✅ provider photo URL

    private let supabase     = SupabaseService.shared.client
    private var currentNonce: String = ""

    // MARK: - Init
    private override init() {
        super.init()
        checkSession()
    }

    // MARK: - Check Existing Session
    func checkSession() {
        Task {
            let installedKey = "app_has_launched_v2"
            let isInstalled  = UserDefaults.standard.bool(forKey: installedKey)

            if !isInstalled {
                print("🆕 Fresh install — showing login")
                await MainActor.run { self.isLoggedIn = false }
                return
            }

            do {
                let session = try await supabase.auth.session
                let userId  = session.user.id.uuidString
                let email   = session.user.email ?? ""

                CoreDataManager.shared.currentUserId = userId
                UserPreferences.shared.loadForUser(userId)

                await MainActor.run {
                    self.currentUserId = userId
                    self.userEmail     = email
                    self.isLoggedIn    = true
                }

                print("✅ Session restored: \(userId.prefix(8))")
                print("   CoreData userId: \(CoreDataManager.shared.currentUserId.prefix(8))")

                // ✅ Load avatar from Supabase metadata on session restore
                let meta = session.user.userMetadata
                if let avatarVal = meta["avatar_url"],
                   case .string(let urlStr) = avatarVal,
                   let url = URL(string: urlStr) {
                    await MainActor.run { self.avatarURL = url }
                    await downloadAndCacheAvatar(from: url, userId: userId)
                }

                await reloadAfterLogin(userId: userId, email: email, name: "")

                await MainActor.run {
                    self.isCheckingSession = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SessionRestored"),
                        object: nil
                    )
                }

                Task {
                    do {
                        try await supabase.auth.refreshSession()
                        print("✅ Token refreshed in background")
                    } catch {
                        print("⚠️ Background refresh failed: \(error)")
                    }
                }

            } catch {
                print("ℹ️ No session found — showing login")
                await MainActor.run {
                    self.isLoggedIn        = false
                    self.currentUserId     = ""
                    self.isCheckingSession = false
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
        let request  = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce           = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: ─────────────────────────────────────
    // MARK: GOOGLE SIGN IN
    // MARK: ─────────────────────────────────────

    func startGoogleSignIn() async {
        await MainActor.run { isLoading = true; errorMessage = "" }

        do {
            guard let windowScene = await UIApplication.shared.connectedScenes
                .first as? UIWindowScene,
                let rootVC = await windowScene.windows.first?.rootViewController
            else {
                await MainActor.run {
                    self.errorMessage = "Cannot find view controller"
                    self.isLoading    = false
                }
                return
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "No ID token from Google"
                    self.isLoading    = false
                }
                return
            }

            let accessToken = result.user.accessToken.tokenString
            let googleName  = result.user.profile?.name  ?? ""
            let googleEmail = result.user.profile?.email ?? ""
            // ✅ Google provides a direct high-res photo URL
            let googlePhoto = result.user.profile?.imageURL(withDimension: 200)

            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider:    .google,
                    idToken:     idToken,
                    accessToken: accessToken
                )
            )

            let userId = session.user.id.uuidString

            await MainActor.run {
                self.currentUserId = userId
                self.userEmail     = googleEmail
                self.userName      = googleName
                self.isLoading     = false
                self.isLoggedIn    = true
                self.avatarURL     = googlePhoto  // ✅ store photo URL
                CoreDataManager.shared.currentUserId = userId
            }

            // ✅ Download and cache Google profile photo
            if let photoURL = googlePhoto {
                await downloadAndCacheAvatar(from: photoURL, userId: userId)
            }

            await reloadAfterLogin(userId: userId, email: googleEmail, name: googleName)

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading    = false
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: SIGN OUT
    // ─────────────────────────────────────────
    func signOut() async {
        print("🚪 Signing out — clearing all data...")
        GIDSignIn.sharedInstance.signOut()
        try? await supabase.auth.signOut()

        let coreData = CoreDataManager.shared
        coreData.clearAllLocalData()
        coreData.currentUserId = ""

        UserDefaults.standard.removeObject(forKey: "userCurrency")
        UserDefaults.standard.removeObject(forKey: "userName_\(currentUserId)")

        await MainActor.run {
            UserPreferences.shared.currency = "USD"
            UserPreferences.shared.userName = ""
            self.isLoggedIn    = false
            self.currentUserId = ""
            self.userName      = ""
            self.userEmail     = ""
            self.errorMessage  = ""
            self.avatarURL     = nil  // ✅ clear avatar on sign out
        }

        let summaryCount = coreData.fetchAllSummaries().count
        print("✅ Sign out complete. Remaining summaries: \(summaryCount)")
    }

    // MARK: ─────────────────────────────────────
    // MARK: RELOAD AFTER LOGIN
    // ─────────────────────────────────────────
    func reloadAfterLogin(userId: String, email: String, name: String) async {
        let coreData = CoreDataManager.shared

        let previousUserId = coreData.currentUserId
        let isUserSwitch   = !previousUserId.isEmpty && previousUserId != userId
        if isUserSwitch {
            print("🔄 User switched: \(previousUserId.prefix(8)) → \(userId.prefix(8))")
            coreData.clearAllLocalData()
        }

        coreData.currentUserId = userId

        let expenseCount = coreData.fetchCategories(type: "expense").count
        if !coreData.categoriesExist() {
            coreData.addDefaultCategories()
            print("✅ Default categories created")
        } else if expenseCount < 20 {
            print("🔄 Refreshing old categories (\(expenseCount) → 35+)")
            coreData.refreshDefaultCategories()
        } else {
            coreData.deduplicateCategories()
            print("✅ Categories OK (\(expenseCount) expense)")
        }

        await MainActor.run { UserPreferences.shared.loadForUser(userId) }

        // ── Step 5: Detect missing transactions ───
        let allTxReq: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        let existingTxCount      = (try? coreData.context.fetch(allTxReq))?.count ?? 0
        let existingSummaryCount = coreData.fetchAllSummaries().count
        let hadNoData            = existingTxCount == 0 && existingSummaryCount == 0
        let isFreshInstall       = CoreDataManager.iCloudEnabledAtLaunch && hadNoData

        if isFreshInstall { print("🆕 Fresh install detected — will poll iCloud in background") }

        let localCount = coreData.fetchAllSummaries().count
        print("📊 Local summaries: \(localCount)")

        // ── Step 6: Restore from Supabase ─────────
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

        // ── Step 7: Background iCloud poll ────────
        let txCountAfterRestore      = (try? coreData.context.fetch(allTxReq))?.count ?? 0
        let summaryCountAfterRestore = coreData.fetchAllSummaries().count
        let needsICloudPoll          = CoreDataManager.iCloudEnabledAtLaunch
            && txCountAfterRestore == 0
            && summaryCountAfterRestore > 0

        if isFreshInstall || needsICloudPoll {
            print("☁️ Transactions missing (\(txCountAfterRestore) txs, \(summaryCountAfterRestore) summaries) — starting iCloud poll")
            startICloudFreshInstallPoll(userId: userId)
        }
    }

    // MARK: - Background iCloud Poll (fresh install only)
    private func startICloudFreshInstallPoll(userId: String) {
        print("☁️ Starting iCloud restore tracking...")

        let coreData      = CoreDataManager.shared
        let summaries     = coreData.fetchAllSummaries()
        let expectedDates = Set(
            summaries.filter { ($0.totalIncome + $0.totalExpense) > 0 }.compactMap { $0.date }
        )
        let totalDays = expectedDates.count

        Task { @MainActor in
            self.isSyncingFromICloud = true
            let prog = ICloudSyncProgress.shared
            prog.reset()
            prog.totalDays    = totalDays
            prog.restoredDays = 0
            print("☁️ Expecting \(totalDays) days of transactions from iCloud")
        }

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("iCloudDataChanged"),
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            guard let self else { return }
            let allTxReq: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            let allTxs = (try? coreData.context.fetch(allTxReq)) ?? []
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = TimeZone.current
            let arrivedDates  = Set(allTxs.compactMap { tx -> String? in
                guard let d = tx.date else { return nil }; return fmt.string(from: d)
            })
            let restoredDays = expectedDates.intersection(arrivedDates).count
            print("☁️ iCloud event: \(allTxs.count) txs, \(restoredDays)/\(totalDays) days")
            ICloudSyncProgress.shared.restoredDays = restoredDays
            TransactionController.shared.loadTodayData()
            HistoryController.shared.loadMonthData()
            if restoredDays >= totalDays && totalDays > 0 {
                print("✅ iCloud restore complete!")
                self.isSyncingFromICloud = false
                ICloudSyncProgress.shared.reset()
                if let obs = observer { NotificationCenter.default.removeObserver(obs); observer = nil }
            }
        }

        // Fallback: aggressive poll every 20s
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while await self.isSyncingFromICloud {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                let allTxReq: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                let allTxs = (try? coreData.context.fetch(allTxReq)) ?? []
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = TimeZone.current
                let arrivedDates = Set(allTxs.compactMap { tx -> String? in
                    guard let d = tx.date else { return nil }; return fmt.string(from: d)
                })
                let restoredDays = expectedDates.intersection(arrivedDates).count
                print("☁️ iCloud poll: \(allTxs.count) txs, \(restoredDays)/\(totalDays) days")
                await MainActor.run {
                    ICloudSyncProgress.shared.restoredDays = restoredDays
                    if allTxs.count > 0 {
                        TransactionController.shared.loadTodayData()
                        HistoryController.shared.loadMonthData()
                        HistoryController.shared.loadCalendarData()
                        NotificationCenter.default.post(name: NSNotification.Name("iCloudDataChanged"), object: nil)
                    }
                    if restoredDays >= totalDays && totalDays > 0 {
                        print("✅ iCloud restore complete!")
                        self.isSyncingFromICloud = false
                        ICloudSyncProgress.shared.reset()
                        if let obs = observer { NotificationCenter.default.removeObserver(obs); observer = nil }
                    }
                }
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: AVATAR DOWNLOAD & CACHE
    // ─────────────────────────────────────────

    /// Downloads photo from Google/Apple URL and saves to App Group cache.
    /// Notifies ProfileView via AvatarLoaded notification.
    func downloadAndCacheAvatar(from url: URL, userId: String) async {
        let cacheURL = avatarCacheURL(for: userId)

        // Already cached — just notify immediately
        if let img = UIImage(contentsOfFile: cacheURL.path) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AvatarLoaded"), object: img
                )
            }
            return
        }

        // Download from provider
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img        = UIImage(data: data),
              let compressed = img.jpegData(compressionQuality: 0.8)
        else {
            print("⚠️ Failed to download avatar from \(url.host ?? "")")
            return
        }

        // Save to App Group (survives reinstall)
        try? compressed.write(to: cacheURL)
        print("✅ Avatar cached from \(url.host ?? "provider")")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("AvatarLoaded"),
                object: UIImage(data: compressed) ?? img
            )
        }
    }

    func avatarCacheURL(for userId: String) -> URL {
        let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.shibbir.DailyFinance")
        let base = groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("avatar_\(userId).jpg")
    }

    // MARK: ─────────────────────────────────────
    // MARK: CREATE PROFILE IF NEEDED
    // ─────────────────────────────────────────
    private func createProfileIfNeeded(userId: String, email: String, name: String) async {
        do {
            let response = try await supabase.from("profiles")
                .select("id").eq("id", value: userId).execute()
            let str    = String(data: response.data, encoding: .utf8) ?? "[]"
            let exists = str != "[]" && str != "[ ]" && str.count > 5
            if exists { print("✅ Profile already exists"); return }

            struct ProfileInsert: Encodable {
                let id: String; let full_name: String; let currency: String; let email: String
            }
            try await supabase.from("profiles")
                .insert(ProfileInsert(id: userId, full_name: name.isEmpty ? email : name,
                                      currency: "USD", email: email))
                .execute()
            print("✅ Profile created for: \(email)")
        } catch { print("⚠️ Profile check/create error: \(error)") }
    }

    // MARK: - Apple Sign In Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode   = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData  = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
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
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData  = credential.identityToken,
              let idToken    = String(data: tokenData, encoding: .utf8)
        else { self.errorMessage = "Apple Sign In failed"; return }

        let firstName  = credential.fullName?.givenName  ?? ""
        let lastName   = credential.fullName?.familyName ?? ""
        let fullName   = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let appleEmail = credential.email ?? ""

        Task {
            await MainActor.run { self.isLoading = true }
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: currentNonce)
                )
                let userId     = session.user.id.uuidString
                let finalEmail = appleEmail.isEmpty ? (session.user.email ?? "") : appleEmail
                let finalName  = fullName.isEmpty ? finalEmail : fullName

                await MainActor.run {
                    self.currentUserId = userId
                    self.userEmail     = finalEmail
                    self.userName      = finalName
                    self.isLoading     = false
                    self.isLoggedIn    = true
                    CoreDataManager.shared.currentUserId = userId
                }

                // ✅ Try avatar from Supabase metadata
                let meta = session.user.userMetadata
                if let avatarVal = meta["avatar_url"],
                   case .string(let urlStr) = avatarVal,
                   let url = URL(string: urlStr) {
                    await MainActor.run { self.avatarURL = url }
                    await downloadAndCacheAvatar(from: url, userId: userId)
                }

                await reloadAfterLogin(userId: userId, email: finalEmail, name: finalName)

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
        if (error as NSError).code == 1001 { print("ℹ️ User cancelled Apple Sign In"); return }
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription; self.isLoading = false }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: APPLE PRESENTATION CONTEXT
// ─────────────────────────────────────────────
extension AuthController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return UIWindow() }
        return window
    }
}
