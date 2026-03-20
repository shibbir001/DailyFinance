//
//  NetworkMonitor.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//
// Helpers/NetworkMonitor.swift
import Network
import Foundation
import Combine

class NetworkMonitor: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Properties
    @Published var isConnected: Bool = false

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(
        label: "NetworkMonitor"
    )

    private init() {
        startMonitoring()
    }

    // MARK: - Start Monitoring
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected =
                    path.status == .satisfied

                // Internet came back online!
                if path.status == .satisfied {
                    print("✅ Internet connected")
                    Task {
                        await SyncService
                            .shared
                            .syncPendingData()
                    }
                } else {
                    print("❌ Internet disconnected")
                }
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Stop Monitoring
    func stopMonitoring() {
        monitor.cancel()
    }
}
