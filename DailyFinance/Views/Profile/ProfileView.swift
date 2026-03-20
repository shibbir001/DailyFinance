// Views/Profile/ProfileView.swift
import SwiftUI
import CloudKit
import PhotosUI
import Supabase

struct ProfileView: View {

    // MARK: - Properties
    @StateObject private var auth = AuthController.shared
    @StateObject private var sync = SyncService.shared
    // No dismiss needed — ProfileView is a tab
    // ✅ Shared preferences — changes propagate everywhere
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    // MARK: - State
    @State private var displayName:    String = ""
    @State private var email:          String = ""
    @State private var isEditingName:  Bool   = false
    @State private var editedName:     String = ""
    @State private var showSignOutAlert:  Bool   = false
    @State private var isSyncing:         Bool   = false
    @State private var syncMessage:       String = ""
    @State private var localRecords:      Int    = 0
    @State private var showCurrencyPicker:  Bool             = false
    @State private var selectedPhoto:       PhotosPickerItem? = nil
    @State private var profileImage:        UIImage?          = nil

    let currencies = ["USD", "GBP", "EUR", "CAD", "AUD"]

    // Currency symbols
    let currencySymbols: [String: String] = [
        "USD": "$", "GBP": "£",
        "EUR": "€", "CAD": "CA$", "AUD": "A$"
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: iCloud Error Banner
                        iCloudErrorBanner

                        // MARK: Avatar + Name
                        avatarSection

                        // MARK: Personal Info
                        personalInfoSection

                        // MARK: Currency
                        // MARK: Theme
                        themeSection

                        currencySection

                        // MARK: Sync
                        syncSection

                        // MARK: iCloud
                        iCloudSection

                        // MARK: Data Info
                        dataSection

                        // MARK: Sign Out
                        signOutButton

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)

            .onAppear { loadUserData() }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await auth.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Avatar Section
    var avatarSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                // ✅ Profile photo or initials
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(
                            color: theme.accent.opacity(0.3),
                            radius: 12
                        )

                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Text(avatarInitial)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // ✅ Camera button to pick photo
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    ZStack {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 28, height: 28)
                            .shadow(
                                color: theme.accent.opacity(0.4),
                                radius: 4
                            )
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                .onChange(of: selectedPhoto) { item in
                    Task {
                        if let data = try? await item?
                            .loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run {
                                profileImage = img
                            }
                            saveProfileImage(data)
                        }
                    }
                }
            }

            // Name + edit
            if isEditingName {
                // Edit mode
                VStack(spacing: 10) {
                    TextField("Your name", text: $editedName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.accent, lineWidth: 1.5)
                        )

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            editedName    = displayName
                            isEditingName = false
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)

                        Button("Save") {
                            saveName()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)

            } else {
                // Display mode
                HStack(spacing: 8) {
                    Text(displayName.isEmpty
                         ? "Tap to add name"
                         : displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(
                            displayName.isEmpty
                            ? .secondary : .primary
                        )

                    Button {
                        editedName    = displayName
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(theme.accent)
                            .font(.title3)
                    }
                }

                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - iCloud Error Banner
    @ViewBuilder
    var iCloudErrorBanner: some View {
        if let error = CoreDataManager.shared.iCloudError {
            HStack(spacing: 12) {
                Image(systemName: error.icon)
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(errorTitle(error))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }

                Spacer()

                // Open Settings button for storage full
                if case .storageFull = error {
                    Button {
                        if let url = URL(
                            string: "App-Prefs:root=CASTLE"
                        ) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Fix")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(errorColor(error))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding()
            .background(errorColor(error))
            .cornerRadius(14)
            .shadow(
                color: errorColor(error).opacity(0.3),
                radius: 8
            )
        }
    }

    func errorTitle(
        _ error: CoreDataManager.ICloudError
    ) -> String {
        switch error {
        case .storageFull:         return "iCloud Storage Full"
        case .accountNotAvailable: return "iCloud Not Available"
        case .networkUnavailable:  return "No Internet Connection"
        case .unknown:             return "iCloud Sync Error"
        }
    }

    func errorColor(
        _ error: CoreDataManager.ICloudError
    ) -> Color {
        switch error {
        case .storageFull:         return .orange
        case .accountNotAvailable: return .red
        case .networkUnavailable:  return .gray
        case .unknown:             return .orange
        }
    }

    // MARK: - Personal Info Section
    var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            sectionHeader("ACCOUNT")

            VStack(spacing: 0) {
                infoRow(
                    icon:  "envelope.fill",
                    color: .blue,
                    title: "Email",
                    value: email.isEmpty ? "—" : email
                )

                Divider().padding(.leading, 52)

                infoRow(
                    icon:  "person.fill",
                    color: .purple,
                    title: "Sign In",
                    value: signInProvider
                )

                Divider().padding(.leading, 52)

                infoRow(
                    icon:  "shield.fill",
                    color: theme.accent,
                    title: "User ID",
                    value: String(auth.currentUserId.prefix(8)) + "..."
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Currency Section
    var currencySection: some View {
        VStack(alignment: .leading, spacing: 0) {

            sectionHeader("PREFERENCES")

            VStack(spacing: 0) {
                // ✅ Currency row — tap to expand
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCurrencyPicker.toggle()
                        }
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                            }
                            Text("Currency")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(preferences.currency)
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Image(systemName: showCurrencyPicker
                                  ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                        .padding()
                    }

                    // ✅ Collapsed by default
                    if showCurrencyPicker {
                        Divider().padding(.leading, 52)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(currencies, id: \.self) { currency in
                                    Button {
                                        preferences.currency = currency
                                        withAnimation {
                                            showCurrencyPicker = false
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(currencySymbols[currency] ?? "$")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Text(currency)
                                                .font(.caption2)
                                        }
                                        .frame(width: 56, height: 52)
                                        .background(
                                            preferences.currency == currency
                                            ? theme.accent
                                            : Color(.systemGroupedBackground)
                                        )
                                        .foregroundColor(
                                            preferences.currency == currency
                                            ? .white : .primary
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    preferences.currency == currency
                                                    ? Color.clear
                                                    : Color.secondary.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Sync Section
    var syncSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            sectionHeader("SYNC")

            // ✅ Single compact row
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: isSyncing
                          ? "arrow.triangle.2.circlepath"
                          : "checkmark.icloud")
                        .foregroundColor(theme.accent)
                        .font(.system(size: 13))
                        .rotationEffect(isSyncing ? .degrees(360) : .zero)
                        .animation(
                            isSyncing
                            ? .linear(duration: 1)
                                .repeatForever(autoreverses: false)
                            : .default,
                            value: isSyncing
                        )
                }

                // Last sync time
                Text(isSyncing ? "Syncing..." : lastSyncText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // ✅ Underlined "Sync Now" text button
                Button {
                    manualSync()
                } label: {
                    Text("Sync Now")
                        .font(.subheadline)
                        .foregroundColor(theme.accent)
                        .underline()
                }
                .disabled(isSyncing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Theme Section
    var themeSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            sectionHeader("APP THEME")

            VStack(spacing: 12) {
                // Current theme label
                HStack {
                    ZStack {
                        Circle()
                            .fill(theme.mediumBg)
                            .frame(width: 34, height: 34)
                        Image(systemName: theme.current.icon)
                            .foregroundColor(theme.accent)
                            .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Theme")
                            .foregroundColor(.primary)
                        Text(theme.current.rawValue)
                            .font(.caption)
                            .foregroundColor(theme.accent)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 14)

                // ✅ Color swatches
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { t in
                        Button {
                            withAnimation(.spring(
                                response: 0.3,
                                dampingFraction: 0.7
                            )) {
                                theme.current = t
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(t.accent)
                                        .frame(width: 36, height: 36)
                                        .shadow(
                                            color: t.accent.opacity(0.4),
                                            radius: theme.current == t ? 8 : 0
                                        )

                                    if theme.current == t {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: t.icon)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .scaleEffect(theme.current == t ? 1.15 : 1.0)

                                Text(t.rawValue)
                                    .font(.system(size: 9))
                                    .foregroundColor(
                                        theme.current == t
                                        ? t.accent : .secondary
                                    )
                                    .fontWeight(
                                        theme.current == t ? .semibold : .regular
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 14)
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - iCloud Section
    var iCloudSection: some View {
        let isCurrentlyActive = CoreDataManager.iCloudEnabledAtLaunch
        let willChangeOnRestart = preferences.iCloudEnabled != isCurrentlyActive

        return VStack(alignment: .leading, spacing: 0) {

            sectionHeader("ICLOUD SYNC")

            VStack(spacing: 0) {

                // iCloud Toggle
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Sync")
                            .foregroundColor(.primary)
                        Text(isCurrentlyActive
                             ? "Active — syncing across devices"
                             : "Sync transactions across all devices")
                            .font(.caption)
                            .foregroundColor(
                                isCurrentlyActive ? .blue : .secondary
                            )
                    }

                    Spacer()

                    Toggle("", isOn: $preferences.iCloudEnabled)
                        .tint(.blue)
                        .labelsHidden()
                }
                .padding()

                // Status message
                Divider().padding(.leading, 52)

                if willChangeOnRestart {
                    // ✅ Show restart prompt
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Restart Required")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text(preferences.iCloudEnabled
                                 ? "Close and reopen the app to activate iCloud sync."
                                 : "Close and reopen the app to disable iCloud sync.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // ✅ Force quit button
                        Button {
                            // Save preference first
                            UserDefaults.standard.synchronize()
                            // Exit app — user reopens fresh
                            exit(0)
                        } label: {
                            Text("Restart")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))

                } else if isCurrentlyActive {
                    // ✅ iCloud is active
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iCloud Sync is Active")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text("All transactions sync automatically across your Apple devices.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                } else {
                    // ✅ iCloud is off
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                        Text("Enable to sync all transactions across your iPhone, iPad and Mac via iCloud.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Data Section
    var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            sectionHeader("DATA")

            VStack(spacing: 0) {
                infoRow(
                    icon:  "internaldrive.fill",
                    color: .gray,
                    title: "Local Records",
                    value: "\(localRecords) days"
                )

                Divider().padding(.leading, 52)

                infoRow(
                    icon:  "icloud.fill",
                    color: .blue,
                    title: "Cloud Backup",
                    value: "Daily totals only"
                )

                Divider().padding(.leading, 52)

                infoRow(
                    icon:  CoreDataManager.iCloudEnabledAtLaunch
                        ? "icloud.fill" : "lock.fill",
                    color: CoreDataManager.iCloudEnabledAtLaunch
                        ? .blue : .gray,
                    title: "Transactions",
                    value: CoreDataManager.iCloudEnabledAtLaunch
                        ? "iCloud synced" : "Device only"
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Sign Out Button
    var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack {
                Image(systemName:
                    "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(14)
        }
    }

    // MARK: - Reusable Components

    // MARK: - Profile Image
    // ✅ Uses CloudKit (already set up) via CKRecord
    // No need for iCloud Documents capability

    private var localImageURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(
                "profile_\(auth.currentUserId).jpg"
            )
    }

    func saveProfileImage(_ data: Data) {
        guard let img        = UIImage(data: data),
              let compressed = img.jpegData(compressionQuality: 0.6)
        else { return }

        // ✅ Save locally immediately
        try? compressed.write(to: localImageURL)
        profileImage = UIImage(data: compressed)
        print("✅ Profile image saved locally")

        // ✅ Save to CloudKit
        Task { await saveImageToCloudKit(compressed) }
    }

    func loadProfileImage() {
        // ✅ Load local first (instant)
        if let img = UIImage(contentsOfFile: localImageURL.path) {
            profileImage = img
            print("✅ Profile image loaded from local")
        }
        // ✅ Delay CloudKit load to ensure auth token is ready
        Task {
            // Wait for auth to be fully ready
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !auth.currentUserId.isEmpty else {
                print("⚠️ No userId — skipping CloudKit image load")
                return
            }
            await loadImageFromCloudKit()
        }
    }

    // MARK: - CloudKit Image Save
    private func saveImageToCloudKit(_ data: Data) async {
        do {
            let container = CKContainer(
                identifier: "iCloud.shibbir-Daily-Finance"
            )
            let db        = container.privateCloudDatabase
            let recordID  = CKRecord.ID(
                recordName: "ProfileImage_\(auth.currentUserId)"
            )

            // Fetch or create record
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch {
                record = CKRecord(
                    recordType: "ProfileImage",
                    recordID: recordID
                )
            }

            // Save image as CKAsset
            let tempURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("profile_upload.jpg")
            try data.write(to: tempURL)

            record["imageAsset"]  = CKAsset(fileURL: tempURL)
            record["userId"]      = auth.currentUserId
            record["updatedAt"]   = Date()

            try await db.save(record)
            try? FileManager.default.removeItem(at: tempURL)
            print("✅ Profile image saved to CloudKit")

        } catch {
            print("❌ CloudKit image save failed: \(error)")
        }
    }

    // MARK: - CloudKit Image Load
    private func loadImageFromCloudKit() async {
        do {
            let container = CKContainer(
                identifier: "iCloud.shibbir-Daily-Finance"
            )
            let db        = container.privateCloudDatabase
            let recordID  = CKRecord.ID(
                recordName: "ProfileImage_\(auth.currentUserId)"
            )

            let record = try await db.record(for: recordID)

            guard let asset = record["imageAsset"] as? CKAsset,
                  let url   = asset.fileURL,
                  let data  = try? Data(contentsOf: url),
                  let img   = UIImage(data: data)
            else { return }

            // Save locally for next launch
            let compressed = img.jpegData(compressionQuality: 0.6)
            try? compressed?.write(to: localImageURL)

            await MainActor.run {
                profileImage = img
                print("✅ Profile image loaded from CloudKit")
            }

        } catch let ckError as CKError {
            switch ckError.code {
            case .unknownItem:
                // No image saved yet — normal for new users
                break
            case .notAuthenticated, .permissionFailure,
                 .accountTemporarilyUnavailable:
                // ✅ Auth not ready (common on Simulator)
                // Will work correctly on real device
                print("ℹ️ CloudKit profile: auth not ready yet")
            default:
                print("ℹ️ CloudKit profile: \(ckError.code.rawValue)")
            }
        } catch {
            // Silent — not critical
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
            .padding(.leading, 4)
    }

    func infoRow(
        icon:  String,
        color: Color,
        title: String,
        value: String
    ) -> some View {
        HStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
            }
            .padding(.leading, 2)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding()
    }

    // MARK: - Computed
    var avatarInitial: String {
        if !displayName.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        if !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }

    var signInProvider: String {
        // Check which provider was used
        let id = auth.currentUserId
        if id.isEmpty { return "Unknown" }
        // Check UserDefaults for provider
        return UserDefaults.standard
            .string(forKey: "signInProvider") ?? "Apple/Google"
    }

    // MARK: - Load User Data
    func loadUserData() {
        // Load from auth session
        Task {
            do {
                let session = try await SupabaseService
                    .shared.client.auth.session
                await MainActor.run {
                    email = session.user.email ?? ""

                    // Load saved name from UserDefaults
                    let savedName = UserDefaults.standard
                        .string(forKey: "userName_\(session.user.id)")
                    displayName = savedName
                        ?? auth.userName
                        ?? ""
                }
            } catch {
                print("❌ Load user error: \(error)")
            }
        }

        // Load currency from UserDefaults
        let saved = UserDefaults.standard
            .string(forKey: "userCurrency") ?? "USD"
        preferences.currency = saved

        // Load local record count
        localRecords = CoreDataManager.shared
            .fetchAllSummaries().count

        // ✅ Load profile image
        loadProfileImage()
    }

    // MARK: - Save Name
    func saveName() {
        displayName   = editedName
        isEditingName = false

        // Save to UserDefaults
        UserDefaults.standard.set(
            editedName,
            forKey: "userName_\(auth.currentUserId)"
        )

        // Update in auth
        auth.userName = editedName

        print("✅ Name saved: \(editedName)")
    }

    // MARK: - Manual Sync
    func manualSync() {
        isSyncing   = true
        syncMessage = ""

        Task {
            await SyncService.shared.syncTodayData()
            await MainActor.run {
                isSyncing   = false
                syncMessage = "✅ Synced successfully!"
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                syncMessage = ""
            }
        }
    }

    // MARK: - Last Sync Text
    func lastSyncText() -> String {
        guard let last = sync.lastSyncTime else {
            return "Never"
        }
        let f        = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: last, relativeTo: Date())
    }
}
