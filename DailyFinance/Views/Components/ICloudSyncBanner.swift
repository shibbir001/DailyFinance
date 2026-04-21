// Views/Components/ICloudSyncBanner.swift
import SwiftUI
import Combine
internal import CoreData

struct ICloudSyncBanner: View {

    @StateObject private var progress = ICloudSyncProgress.shared
    @State private var isRefreshing   = false
    @State private var isDismissed    = false

    var body: some View {
        if isDismissed { return AnyView(EmptyView()) }

        return AnyView(
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundColor(.white)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Restoring from iCloud")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if progress.totalDays > 0 {
                        Text("\(progress.restoredDays) of \(progress.totalDays) days restored")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("Waiting for iCloud…")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // ✅ Dismiss button
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                            AuthController.shared.isSyncingFromICloud = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if progress.totalDays > 0 {
                        Text("\(Int(progress.fraction * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }

            // Progress bar
            if progress.totalDays > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.3)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(
                                width: max(0, geo.size.width * progress.fraction),
                                height: 6
                            )
                            .animation(.easeInOut(duration: 0.5), value: progress.fraction)
                    }
                }
                .frame(height: 6)
            }

            // Bottom row: hint + refresh button
            HStack {
                Text("iCloud delivers in batches. May take a few minutes.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // ✅ Manual refresh button
                Button {
                    forceRefresh()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise").font(.caption2)
                        Text("Refresh").font(.caption2).fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .disabled(isRefreshing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.51, blue: 0.96),
                    Color(red: 0.39, green: 0.40, blue: 0.95)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .blue.opacity(0.3), radius: 8)
        )
    }

    // MARK: - Force Refresh
    func forceRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await MainActor.run {
                CoreDataManager.shared.context.refreshAllObjects()
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                TransactionController.shared.loadTodayData()
                HistoryController.shared.loadMonthData()
                HistoryController.shared.loadCalendarData()
                NotificationCenter.default.post(
                    name: NSNotification.Name("iCloudDataChanged"),
                    object: nil
                )
                isRefreshing = false
            }
        }
    }
}

// MARK: - Sync Progress Model
class ICloudSyncProgress: ObservableObject {

    static let shared = ICloudSyncProgress()

    @Published var totalDays:    Int = 0
    @Published var restoredDays: Int = 0

    var fraction: Double {
        guard totalDays > 0 else { return 0 }
        return min(Double(restoredDays) / Double(totalDays), 1.0)
    }

    var isComplete: Bool {
        totalDays > 0 && restoredDays >= totalDays
    }

    private init() {}

    func reset() {
        totalDays    = 0
        restoredDays = 0
    }
}
