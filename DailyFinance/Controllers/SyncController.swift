// Controllers/SyncController.swift
import Foundation
import BackgroundTasks

class SyncController {

    // MARK: - Singleton
    static let shared = SyncController()

    private let sync    = SyncService.shared
    private let network = NetworkMonitor.shared

    // ✅ Must match Info.plist exactly
    private let bgTaskId = "shibbir-Daily-Finance.sync"

    private init() {}

    // MARK: - Register Background Task
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskId,
            using: nil
        ) { task in
            self.handleBackgroundSync(
                task: task as! BGAppRefreshTask
            )
        }
        print("✅ Background sync registered: \(bgTaskId)")
    }

    // MARK: - Handle Background Sync
    private func handleBackgroundSync(
        task: BGAppRefreshTask
    ) {
        scheduleNextBackgroundSync()

        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }

        Task {
            await sync.syncTodayData()
            task.setTaskCompleted(success: true)
            print("✅ Background sync complete")
        }
    }

    // MARK: - Schedule Next
    func scheduleNextBackgroundSync() {
        let request = BGAppRefreshTaskRequest(
            identifier: bgTaskId
        )

        var components      = DateComponents()
        components.hour     = 23
        components.minute   = 55

        let midnight = Calendar.current.nextDate(
            after:          Date(),
            matching:       components,
            matchingPolicy: .nextTime
        )

        request.earliestBeginDate = midnight

        do {
            try BGTaskScheduler.shared.submit(request)
            print("⏰ Next sync scheduled")
        } catch {
            print("❌ Schedule error: \(error)")
        }
    }

    // MARK: - App Lifecycle
    func appDidEnterBackground() {
        print("📱 App backgrounded — syncing...")
        sync.scheduleDailySync()
        scheduleNextBackgroundSync()
    }

    func appDidBecomeActive() {
        print("📱 App active — checking pending sync...")
        Task {
            await sync.syncPendingData()
        }
    }
}
