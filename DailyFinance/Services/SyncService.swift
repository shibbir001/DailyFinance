// Services/SyncService.swift
import Foundation
import Supabase
import Combine
internal import CoreData

// MARK: - Upload Model (totals only)
struct DailyDataUpload: Encodable {
    let user_id:       String
    let date:          String
    let total_income:  Double
    let total_expense: Double
    let net_balance:   Double
    let uploaded_at:   String
}

// MARK: - Download Model
struct DailyDataRecord: Decodable {
    let user_id:       String
    let date:          String
    let total_income:  Double
    let total_expense: Double
    let net_balance:   Double

    enum CodingKeys: String, CodingKey {
        case user_id, date
        case total_income, total_expense, net_balance
    }
}



// MARK: - SyncService
class SyncService: ObservableObject {

    // MARK: - Singleton
    static let shared = SyncService()

    @Published var isSyncing:    Bool   = false
    @Published var lastSyncTime: Date?  = nil
    @Published var syncError:    String = ""

    private let supabase = SupabaseService.shared.client
    private let coreData = CoreDataManager.shared
    private let network  = NetworkMonitor.shared
    private let lastSyncKey = "lastSyncTime"

    private init() {
        if let saved = UserDefaults.standard
            .object(forKey: lastSyncKey) as? Date {
            lastSyncTime = saved
        }
    }

    // MARK: - Main Sync
    func syncTodayData() async {
        guard network.isConnected else {
            print("📵 Offline — sync skipped")
            return
        }

        // ✅ Don't sync if CoreData userId not set yet
        guard !coreData.currentUserId.isEmpty else {
            print("⏳ Sync skipped — userId not ready yet")
            return
        }

        guard let userId = await getCurrentUserId() else {
            print("❌ Sync failed — no Supabase session")
            return
        }

        print("🔄 Sync starting for user: \(userId.prefix(8))")
        await MainActor.run { isSyncing = true }

        do {
            // ✅ Filter unsynced by current user only
            let allUnsynced = coreData.fetchUnsyncedSummaries()
            let unsynced    = allUnsynced.filter {
                $0.userId == userId || $0.userId == nil
            }

            print("📤 Unsynced summaries: \(unsynced.count)")
            for s in unsynced {
                print("   → \(s.date ?? "?") income=\(s.totalIncome) expense=\(s.totalExpense) userId=\(s.userId ?? "nil")")
            }

            if unsynced.isEmpty {
                print("✅ Nothing to sync")
                await MainActor.run {
                    self.isSyncing = false
                }
                return
            }

            for summary in unsynced {
                try await uploadSummary(
                    summary: summary,
                    userId:  userId
                )
            }

            await MainActor.run {
                self.lastSyncTime = Date()
                UserDefaults.standard.set(
                    Date(), forKey: self.lastSyncKey)
                self.isSyncing = false
            }
            print("✅ Sync complete! \(unsynced.count) summaries uploaded")

        } catch {
            print("❌ Sync error: \(error)")
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
        }
    }

    // MARK: - Upload Summary
    private func uploadSummary(
        summary: DailySummaryEntity,
        userId:  String
    ) async throws {
        let dateStr = summary.date ?? ""
        print("📤 Uploading: \(dateStr) income=\(summary.totalIncome) expense=\(summary.totalExpense)")

        let payload = DailyDataUpload(
            user_id:       userId,
            date:          dateStr,
            total_income:  summary.totalIncome,
            total_expense: summary.totalExpense,
            net_balance:   summary.netBalance,
            uploaded_at:   formatISO(Date())
        )

        do {
            try await supabase
                .from("daily_data")
                .upsert(payload, onConflict: "user_id,date")
                .execute()

            coreData.markAsSynced(summary)
            print("✅ Uploaded to Supabase: \(dateStr)")
        } catch {
            print("❌ Upload failed for \(dateStr): \(error)")
            throw error
        }
    }

    // MARK: - Sync Specific Date
    // ✅ Called immediately after add/delete
    // Only uploads the changed date's summary
    func syncDate(_ date: Date) async {
        guard NetworkMonitor.shared.isConnected else {
            return
        }
        guard let userId = await getCurrentUserId()
        else { return }

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString       = formatter.string(from: date)

        guard let summary = coreData
            .fetchDailySummary(for: dateString)
        else {
            print("⚠️ No summary for: \(dateString)")
            return
        }

        do {
            try await uploadSummary(
                summary: summary,
                userId:  userId
            )
            print("✅ Synced: \(dateString)")
        } catch {
            print("❌ Sync error: \(error)")
        }
    }

    // MARK: - Sync Pending
    func syncPendingData() async {
        let unsynced: [DailySummaryEntity] =
            coreData.fetchUnsyncedSummaries()
        guard !unsynced.isEmpty else { return }
        await syncTodayData()
    }

    // MARK: - Restore All Data from Supabase
    func restoreAllData() async {
        guard network.isConnected else {
            print("📵 Offline — cannot restore")
            return
        }
        guard let userId = await getCurrentUserId()
        else { return }

        await MainActor.run { isSyncing = true }
        print("📥 Restoring daily summaries from Supabase...")

        do {
            let response = try await supabase
                .from("daily_data")
                .select("user_id,date,total_income,total_expense,net_balance")
                .eq("user_id", value: userId)
                .order("date", ascending: true)
                .execute()

            let records = try JSONDecoder().decode(
                [DailyDataRecord].self,
                from: response.data
            )

            print("📥 Found \(records.count) days to restore")

            if records.isEmpty {
                let localCount = coreData.fetchAllSummaries().count
                if localCount > 0 {
                    print("⚠️ Server empty but local has \(localCount) records")
                    print("   Local data belongs to different user — clearing!")
                    coreData.clearAllLocalData()
                }
            } else {
                for record in records {
                    restoreSummary(record)
                }
                coreData.save()
            }

            // Deduplicate
            coreData.deduplicateSummaries()

            print("✅ Restore complete! \(records.count) days")

            await MainActor.run {
                self.isSyncing    = false
                self.lastSyncTime = Date()
                HistoryController.shared.loadCalendarData()
                HistoryController.shared.loadMonthData()
                TransactionController.shared.loadTodayData()
                TransactionController.shared.loadCategories()
                NotificationCenter.default.post(
                    name: NSNotification.Name("DataRestored"),
                    object: nil
                )
            }

        } catch {
            print("❌ Restore error: \(error)")
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
        }
    }

    // MARK: - Restore Single Summary
    private func restoreSummary(_ record: DailyDataRecord) {
        let normalizedUserId = record.user_id.uppercased()
        if let existing = coreData.fetchDailySummary(for: record.date) {
            existing.totalIncome  = record.total_income
            existing.totalExpense = record.total_expense
            existing.netBalance   = record.net_balance
            existing.isSynced     = true
            existing.userId       = normalizedUserId
        } else {
            let summary           = DailySummaryEntity(context: coreData.context)
            summary.id            = UUID()
            summary.date          = record.date
            summary.totalIncome   = record.total_income
            summary.totalExpense  = record.total_expense
            summary.netBalance    = record.net_balance
            summary.isSynced      = true
            summary.userId        = normalizedUserId
        }
        print("✅ Restored summary: \(record.date) | income: \(record.total_income) | expense: \(record.total_expense) | userId: \(normalizedUserId.prefix(8))")
    }

    // MARK: - Schedule
    func scheduleDailySync() {
        Task { await syncTodayData() }
    }

    // MARK: - Helpers
    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }

    private func formatISO(_ date: Date) -> String {
        return ISO8601DateFormatter().string(from: date)
    }
}
