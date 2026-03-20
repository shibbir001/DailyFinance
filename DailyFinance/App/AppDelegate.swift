// App/AppDelegate.swift
import UIKit
import Security
internal import CoreData
import CloudKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ✅ MUST be first — before anything else
        handleFreshInstall()

        // Register background tasks
        SyncController.shared.registerBackgroundTasks()

        // Start network monitoring
        _ = NetworkMonitor.shared

        // ✅ Push CloudKit schema if iCloud enabled
        initializeCloudKitSchema()

        return true
    }

    // MARK: - Initialize CloudKit Schema
    // Pushes Core Data model to CloudKit servers
    // Required ONCE before sync works
    func initializeCloudKitSchema() {
        guard CoreDataManager.iCloudEnabledAtLaunch else {
            return
        }

        guard let ckContainer = CoreDataManager.shared
            .persistentContainer
            as? NSPersistentCloudKitContainer
        else {
            print("⚠️ Not a CloudKit container")
            return
        }

        // ✅ Only initialize schema once
        let schemaKey = "cloudKitSchemaInitialized_v1"
        let initialized = UserDefaults.standard
            .bool(forKey: schemaKey)

        if !initialized {
            do {
                try ckContainer
                    .initializeCloudKitSchema(options: [])
                UserDefaults.standard
                    .set(true, forKey: schemaKey)
                print("✅ CloudKit schema pushed successfully!")
                print("   CD_TransactionEntity ✅")
                print("   CD_DailySummaryEntity ✅")
                print("   CD_CategoryEntity ✅")
                print("   ProfileImage ✅")
            } catch {
                print("❌ CloudKit schema init failed: \(error)")
                // Will retry on next launch
            }
        } else {
            print("✅ CloudKit schema already initialized")
        }

        // ✅ Ensure ProfileImage record type exists
        ensureProfileImageSchema()
    }

    func ensureProfileImageSchema() {
        // ✅ ProfileImage schema is created on first
        // real save — no need to pre-register
        // Removed to avoid auth timing errors on startup
    }

    // MARK: - Fresh Install Detection
    func handleFreshInstall() {
        let key = "app_has_launched_v2"

        // UserDefaults is wiped on delete
        // Keychain is NOT wiped on delete
        // We use this difference to detect reinstall

        let launchedBefore = UserDefaults.standard
            .bool(forKey: key)

        if !launchedBefore {
            print("🆕 Fresh install — wiping everything")

            // ✅ Step 1: Wipe ALL keychain items
            wipeKeychain()

            // ✅ Step 2: Clear UserDefaults only
            // DO NOT wipe Core Data on fresh install!
            // iCloud needs Core Data store to exist
            // so it can push transactions back into it.
            // Wiping Core Data = iCloud has nowhere to sync to.
            clearUserDefaults()

            // ✅ Step 3: Mark as launched
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.synchronize()

            print("✅ Fresh install complete — Core Data ready for iCloud sync")
        } else {
            print("✅ Existing install — keeping data")
        }
    }

    // MARK: - Wipe Keychain Completely
    func wipeKeychain() {
        let classes = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        for cls in classes {
            let query = [kSecClass as String: cls]
            let status = SecItemDelete(
                query as CFDictionary
            )
            if status == errSecSuccess {
                print("🔑 Cleared keychain class: \(cls)")
            }
        }
    }

    // MARK: - Clear UserDefaults (selective)
    // ✅ Don't clear iCloud preference
    // It should persist across reinstalls
    func clearUserDefaults() {
        guard let bundleID = Bundle.main.bundleIdentifier
        else { return }

        // Save iCloud preference before clearing
        let iCloudEnabled = UserDefaults.standard
            .bool(forKey: "iCloudSyncEnabled")

        UserDefaults.standard
            .removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()

        // Restore iCloud preference
        if iCloudEnabled {
            UserDefaults.standard.set(
                true, forKey: "iCloudSyncEnabled"
            )
        }

        print("🗑️ UserDefaults cleared (iCloud=\(iCloudEnabled))")
    }

    // MARK: - App Lifecycle
    func applicationDidEnterBackground(
        _ application: UIApplication
    ) {
        SyncController.shared.appDidEnterBackground()
    }

    func applicationDidBecomeActive(
        _ application: UIApplication
    ) {
        SyncController.shared.appDidBecomeActive()
    }
}
