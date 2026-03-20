// Models/CoreData/CoreDataManager.swift
internal import CoreData
import CloudKit
import Foundation
import Combine

class CoreDataManager {

    // MARK: - Singleton
    static let shared = CoreDataManager()

    // MARK: - Current User
    var currentUserId: String = ""

    // MARK: - iCloud Preference
    // ✅ Read once at startup — determines which
    // container to build. Changing requires restart.
    static let iCloudEnabledAtLaunch: Bool = {
        UserDefaults.standard.bool(
            forKey: "iCloudSyncEnabled"
        )
    }()

    var isICloudEnabled: Bool {
        get {
            UserDefaults.standard.bool(
                forKey: "iCloudSyncEnabled"
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: "iCloudSyncEnabled"
            )
            print(newValue
                ? "☁️ iCloud will enable on next launch"
                : "💾 iCloud will disable on next launch"
            )
        }
    }

    // MARK: - Core Data Stack
    // ✅ Built ONCE using launch-time preference
    lazy var persistentContainer: NSPersistentContainer = {
        buildContainer(
            useICloud: CoreDataManager.iCloudEnabledAtLaunch
        )
    }()

    // MARK: - Build Container
    private func buildContainer(
        useICloud: Bool
    ) -> NSPersistentContainer {

        if useICloud {
            print("☁️ Core Data: Building iCloud container...")
            return buildCloudKitContainer()
        } else {
            print("💾 Core Data: Building local container...")
            return buildLocalContainer()
        }
    }

    // MARK: - iCloud Error State
    @Published var iCloudError: ICloudError? = nil

    enum ICloudError {
        case storageFull
        case accountNotAvailable
        case networkUnavailable
        case unknown(String)

        var message: String {
            switch self {
            case .storageFull:
                return "Your iCloud storage is full. Please free up space or upgrade your iCloud plan to continue syncing transactions."
            case .accountNotAvailable:
                return "iCloud account is not available. Please sign in to iCloud in Settings."
            case .networkUnavailable:
                return "No internet connection. iCloud sync will resume when connected."
            case .unknown(let msg):
                return "iCloud sync error: \(msg)"
            }
        }

        var icon: String {
            switch self {
            case .storageFull:         return "icloud.slash.fill"
            case .accountNotAvailable: return "person.crop.circle.badge.xmark"
            case .networkUnavailable:  return "wifi.slash"
            case .unknown:             return "exclamationmark.icloud"
            }
        }
    }

    // MARK: - CloudKit Container
    private func buildCloudKitContainer() -> NSPersistentContainer {
        let container = NSPersistentCloudKitContainer(
            name: "DailyFinance"
        )

        guard let description = container
            .persistentStoreDescriptions.first else {
            fatalError("No store description found")
        }

        // ✅ Set CloudKit container identifier
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(
                containerIdentifier:
                    "iCloud.shibbir-Daily-Finance"
            )

        // ✅ Required for CloudKit sync
        description.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        description.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )

        // ✅ Migration
        description.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption
        )
        description.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption
        )

        container.loadPersistentStores { desc, error in
            if let error = error {
                print("❌ CloudKit store failed: \(error)")
                // ✅ Detect specific error types
                DispatchQueue.main.async {
                    self.handleCloudKitError(error)
                }
            } else {
                print("✅ CloudKit store loaded: \(desc.url?.lastPathComponent ?? "")")
                DispatchQueue.main.async {
                    self.iCloudError = nil
                }
            }
        }

        // ✅ Critical: auto merge remote changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy =
            NSMergeByPropertyObjectTrumpMergePolicy

        // ✅ Listen for remote changes with debounce
        var debounceTimer: Timer?
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: 1.5,
                repeats: false
            ) { _ in
                print("☁️ iCloud sync complete — refreshing UI")
                // ✅ Reload immediately
                DispatchQueue.main.async {
                    TransactionController.shared.loadTodayData()
                    HistoryController.shared.loadCalendarData()
                    HistoryController.shared.loadMonthData()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("iCloudDataChanged"),
                        object: nil
                    )
                }
                // ✅ Poll for iCloud transactions arriving late
                // iCloud can take 30s-5min to deliver
                // Track previous count to detect new arrivals
                var lastKnownCount = 0
                for delay in [3.0, 10.0, 30.0, 60.0, 120.0, 180.0, 300.0] {
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + delay
                    ) {
                        // Count ALL transactions (not just today)
                        let req: NSFetchRequest<TransactionEntity>
                            = TransactionEntity.fetchRequest()
                        let total = (try? CoreDataManager.shared
                            .context.fetch(req))?.count ?? 0
                        let todayCount = CoreDataManager.shared
                            .fetchTransactions(for: Date()).count
                        print("🔄 iCloud poll (\(Int(delay))s): total=\(total) today=\(todayCount)")

                        // Refresh UI whenever new transactions arrive
                        TransactionController.shared.loadTodayData()
                        HistoryController.shared.loadMonthData()
                        HistoryController.shared.loadCalendarData()
                        NotificationCenter.default.post(
                            name: NSNotification.Name("iCloudDataChanged"),
                            object: nil
                        )
                    }
                }
            }
        }

        // ✅ Listen for CloudKit account changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object:  nil,
            queue:   .main
        ) { _ in
            print("☁️ iCloud account changed")
            self.checkCloudKitStatus()
        }

        print("✅ CloudKit container ready")
        return container
    }

    // MARK: - Handle CloudKit Errors
    private func handleCloudKitError(_ error: Error) {
        let nsError = error as NSError
        let errorCode = nsError.code

        print("🔍 CloudKit error code: \(errorCode)")
        print("   Domain: \(nsError.domain)")

        // CKError codes
        switch errorCode {
        case 22: // CKError.quotaExceeded
            print("❌ iCloud storage is FULL")
            iCloudError = .storageFull

        case 9:  // CKError.notAuthenticated
            print("❌ iCloud account not available")
            iCloudError = .accountNotAvailable

        case 4:  // CKError.networkUnavailable
            print("❌ Network unavailable")
            iCloudError = .networkUnavailable

        default:
            // ✅ App still works locally even with error
            print("⚠️ CloudKit error \(errorCode): \(error.localizedDescription)")
            // Don't show error for minor issues
            // Only show for critical ones
            if nsError.domain == "NSCocoaErrorDomain" &&
               errorCode == 134060 {
                // Store migration error — ignore
                return
            }
            iCloudError = .unknown(error.localizedDescription)
        }

        // ✅ IMPORTANT: App still works locally!
        // Core Data saves locally regardless of iCloud errors
        print("ℹ️ App continues working locally")
    }

    // MARK: - Check CloudKit Account Status
    func checkCloudKitStatus() {
        CKContainer(
            identifier: "iCloud.shibbir-Daily-Finance"
        ).accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("✅ iCloud account available")
                    self.iCloudError = nil
                case .noAccount:
                    self.iCloudError = .accountNotAvailable
                case .restricted:
                    self.iCloudError = .accountNotAvailable
                default:
                    break
                }
            }
        }
    }

    // MARK: - Local Container
    private func buildLocalContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "DailyFinance")

        let description = container
            .persistentStoreDescriptions.first
        description?.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption
        )
        description?.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption
        )

        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Local store failed: \(error)")
            }
        }

        print("✅ Local container ready")
        return container
    }

    // MARK: - No rebuild needed
    // Container is built once at launch
    // iCloud change takes effect on next app start

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private init() {}

    // MARK: - Save Context
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: TRANSACTION OPERATIONS
    // ─────────────────────────────────────────

    // MARK: - Add Transaction
    // ✅ Smart: ADDS to existing summary
    // preserves restored cloud data
    @discardableResult
    func addTransaction(
        type:     String,
        amount:   Double,
        category: String,
        note:     String,
        date:     Date
    ) -> TransactionEntity {

        // ✅ Generate UUID first — use it to check duplicates
        let newId = UUID()

        // ✅ Check if transaction with same details
        // was already saved in last 5 seconds
        // (prevents double-save from UI/CloudKit)
        let recentCheck = fetchTransactions(for: date)
        let isDuplicate = recentCheck.contains { tx in
            tx.amount   == amount &&
            tx.type     == type &&
            tx.category == category &&
            tx.note     == (note.isEmpty ? category : note) &&
            abs((tx.date ?? Date()).timeIntervalSinceNow) < 5
        }

        if isDuplicate {
            print("⚠️ Duplicate transaction prevented!")
            // Return existing transaction
            return recentCheck.first { tx in
                tx.amount == amount && tx.type == type
            } ?? TransactionEntity(context: context)
        }

        // Save transaction record
        let tx      = TransactionEntity(context: context)
        tx.id       = newId
        tx.type     = type
        tx.amount   = amount
        tx.category = category
        tx.note     = note.isEmpty ? category : note
        tx.date     = date
        tx.isSynced = false
        // ✅ Always save uppercase userId
        // Prevents future mismatch with iCloud sync
        tx.userId   = currentUserId.isEmpty
            ? nil : currentUserId.uppercased()

        save()

        // ✅ Smart update — adds to existing summary
        smartUpdateSummary(
            for:       date,
            newType:   type,
            newAmount: amount
        )

        print("✅ Transaction saved: \(type) \(amount) on \(date)")
        return tx
    }

    // MARK: - Delete Transaction (Smart Subtract)
    // ✅ Subtracts deleted amount from existing summary
    // preserves other restored data
    func deleteTransactionSmart(_ tx: TransactionEntity) {
        let date   = tx.date   ?? Date()
        let type   = tx.type   ?? "expense"
        let amount = tx.amount

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString       = formatter.string(from: date)

        // Delete transaction first
        context.delete(tx)
        save()

        // ✅ SUBTRACT from existing summary
        if let summary = fetchDailySummary(for: dateString) {
            if type == "income" {
                summary.totalIncome = max(
                    0, summary.totalIncome - amount
                )
            } else {
                summary.totalExpense = max(
                    0, summary.totalExpense - amount
                )
            }
            summary.netBalance = summary.totalIncome
                - summary.totalExpense
            summary.isSynced   = false
            save()

            print("✅ Subtracted from summary: \(dateString)")
            print("   income=\(summary.totalIncome) expense=\(summary.totalExpense)")
        }
    }

    // MARK: - Smart Summary Update (Add)
    // ✅ Adds new transaction to existing summary
    // Does NOT recalculate from transactions
    // This preserves restored cloud summaries
    private func smartUpdateSummary(
        for date:    Date,
        newType:     String,
        newAmount:   Double
    ) {
        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone   = TimeZone.current  // ✅ local timezone
        let dateString       = formatter.string(from: date)

        if let existing = fetchDailySummary(for: dateString) {
            // ✅ ADD to existing (preserves restored data)
            if newType == "income" {
                existing.totalIncome  += newAmount
            } else {
                existing.totalExpense += newAmount
            }
            existing.netBalance = existing.totalIncome
                - existing.totalExpense
            existing.isSynced   = false
            // ✅ Always update userId to current user
            existing.userId     = currentUserId.isEmpty
                ? existing.userId : currentUserId
            save()

            print("✅ Added to existing summary: \(dateString)")
            print("   income=\(existing.totalIncome) expense=\(existing.totalExpense) isSynced=false userId=\(existing.userId?.prefix(8) ?? "nil")")

        } else {
            // ✅ No summary exists — create new one
            let summary           = DailySummaryEntity(context: context)
            summary.id            = UUID()
            summary.date          = dateString
            summary.totalIncome   = newType == "income" ? newAmount : 0
            summary.totalExpense  = newType == "expense" ? newAmount : 0
            summary.netBalance    = newType == "income" ? newAmount : -newAmount
            summary.isSynced      = false
            summary.userId        = currentUserId.isEmpty
                ? nil : currentUserId
            save()

            print("✅ New summary created: \(dateString)")
            print("   income=\(summary.totalIncome) expense=\(summary.totalExpense) isSynced=false userId=\(summary.userId?.prefix(8) ?? "nil")")
        }
    }

    // MARK: - Update Daily Summary (Recalculate)
    // ✅ Only recalculates if we have local transactions
    // Preserves cloud summaries when no local transactions
    func updateDailySummary(for date: Date) {
        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone   = TimeZone.current  // ✅ local timezone
        let dateString       = formatter.string(from: date)

        let transactions = fetchTransactions(for: date)

        if let existing = fetchDailySummary(for: dateString) {
            if !transactions.isEmpty {
                // ✅ Have transactions → recalculate
                let income  = transactions
                    .filter  { $0.type == "income" }
                    .reduce(0) { $0 + $1.amount }
                let expense = transactions
                    .filter  { $0.type == "expense" }
                    .reduce(0) { $0 + $1.amount }

                existing.totalIncome  = income
                existing.totalExpense = expense
                existing.netBalance   = income - expense
                existing.isSynced     = false
                existing.userId       = currentUserId.isEmpty
                    ? existing.userId : currentUserId
                save()

                print("✅ Summary recalculated: \(dateString)")
            } else {
                // ✅ No local transactions →
                // keep existing cloud summary intact!
                print("ℹ️ No local transactions for \(dateString)")
                print("   Keeping cloud summary: income=\(existing.totalIncome) expense=\(existing.totalExpense)")
            }
        } else if !transactions.isEmpty {
            // ✅ No summary yet → create from transactions
            let income  = transactions
                .filter  { $0.type == "income" }
                .reduce(0) { $0 + $1.amount }
            let expense = transactions
                .filter  { $0.type == "expense" }
                .reduce(0) { $0 + $1.amount }

            let summary           = DailySummaryEntity(context: context)
            summary.id            = UUID()
            summary.date          = dateString
            summary.totalIncome   = income
            summary.totalExpense  = expense
            summary.netBalance    = income - expense
            summary.isSynced      = false
            summary.userId        = currentUserId.isEmpty
                ? nil : currentUserId
            save()
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: FETCH OPERATIONS
    // ─────────────────────────────────────────

    // MARK: - Fetch Transactions by Date
    func fetchTransactions(
        for date: Date
    ) -> [TransactionEntity] {

        let request: NSFetchRequest<TransactionEntity>
            = TransactionEntity.fetchRequest()

        let calendar = Calendar.current
        let start    = calendar.startOfDay(for: date)
        let end      = calendar.date(
            byAdding: .day, value: 1, to: start
        )!


        if currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                start as CVarArg,
                end   as CVarArg
            )
        } else {
            // ✅ Case-insensitive userId match
            // Handles uppercase (Apple) vs lowercase (iCloud sync)
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND userId ==[c] %@",
                start as CVarArg,
                end   as CVarArg,
                currentUserId
            )
        }

        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false)
        ]

        do {
            let results = try context.fetch(request)
            // ✅ Debug: show what userId values exist in Core Data

            return results
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    // MARK: - Fetch Month Transactions
    func fetchTransactions(
        month: Int,
        year:  Int
    ) -> [TransactionEntity] {

        let request: NSFetchRequest<TransactionEntity>
            = TransactionEntity.fetchRequest()

        var components   = DateComponents()
        components.year  = year
        components.month = month
        components.day   = 1

        let calendar  = Calendar.current
        let startDate = calendar.date(from: components)!
        let endDate   = calendar.date(
            byAdding: .month, value: 1, to: startDate
        )!

        if currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startDate as CVarArg,
                endDate   as CVarArg
            )
        } else {
            // ✅ Case-insensitive userId match
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND (userId ==[c] %@ OR userId == nil OR userId == '')",
                startDate as CVarArg,
                endDate   as CVarArg,
                currentUserId
            )
        }

        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    // MARK: - Fetch Daily Summary
    func fetchDailySummary(
        for dateString: String
    ) -> DailySummaryEntity? {

        let request: NSFetchRequest<DailySummaryEntity>
            = DailySummaryEntity.fetchRequest()

        request.predicate  = NSPredicate(
            format: "date == %@", dateString
        )
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Fetch error: \(error)")
            return nil
        }
    }

    // ✅ Fetch daily summary using a Date object
    // Always uses local timezone for date string
    func fetchDailySummary(for date: Date) -> DailySummaryEntity? {
        let fmt          = DateFormatter()
        fmt.dateFormat   = "yyyy-MM-dd"
        fmt.timeZone     = TimeZone.current
        let dateString   = fmt.string(from: date)
        return fetchDailySummary(for: dateString)
    }

    // MARK: - Fetch All Summaries
    func fetchAllSummaries() -> [DailySummaryEntity] {

        let request: NSFetchRequest<DailySummaryEntity>
            = DailySummaryEntity.fetchRequest()

        // ✅ Filter by current user
        // Use case-insensitive match to handle
        // lowercase (Supabase) vs uppercase (Apple) UUIDs
        if !currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "userId ==[c] %@",
                currentUserId
            )
        }

        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    // MARK: - Fetch Unsynced Summaries
    func fetchUnsyncedSummaries() -> [DailySummaryEntity] {

        let request: NSFetchRequest<DailySummaryEntity>
            = DailySummaryEntity.fetchRequest()

        // ✅ Filter by userId AND isSynced
        if currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "isSynced == false"
            )
        } else {
            request.predicate = NSPredicate(
                format: "isSynced == false AND (userId == %@ OR userId == nil OR userId == '')",
                currentUserId
            )
        }

        do {
            let results = try context.fetch(request)
            print("🔍 fetchUnsyncedSummaries: found \(results.count) for userId=\(currentUserId.prefix(8))")
            return results
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    // MARK: - Check Empty
    func isDataEmpty() -> Bool {
        return fetchAllSummaries().isEmpty
    }

    // MARK: - Mark Synced
    func markAsSynced(_ summary: DailySummaryEntity) {
        summary.isSynced = true
        save()
    }

    // MARK: ─────────────────────────────────────
    // MARK: CATEGORY OPERATIONS
    // ─────────────────────────────────────────

    func addDefaultCategories() {
        let defaults: [(String, String, String, String)] = [
            // INCOME
            ("Salary",       "income",  "🏦", "#22C55E"),
            ("Freelance",    "income",  "🎯", "#10B981"),
            ("Business",     "income",  "🚀", "#059669"),
            ("Investment",   "income",  "📊", "#0D9488"),
            ("Rental",       "income",  "🏡", "#0891B2"),
            ("Gift",         "income",  "🎁", "#7C3AED"),
            ("Bonus",        "income",  "⭐️", "#D97706"),
            ("Refund",       "income",  "🔄", "#2563EB"),
            ("Side Hustle",  "income",  "💡", "#DB2777"),
            // EXPENSE — Food
            ("Groceries",    "expense", "🛒", "#F97316"),
            ("Restaurant",   "expense", "🍽️", "#EF4444"),
            ("Coffee",       "expense", "☕️", "#92400E"),
            ("Alcohol",      "expense", "🍷", "#BE123C"),
            // EXPENSE — Home
            ("Rent",         "expense", "🏠", "#64748B"),
            ("Utilities",    "expense", "⚡️", "#F59E0B"),
            ("Internet",     "expense", "📡", "#3B82F6"),
            ("Furniture",    "expense", "🛋️", "#78716C"),
            ("Repairs",      "expense", "🔧", "#6B7280"),
            // EXPENSE — Transport
            ("Fuel",         "expense", "⛽️", "#DC2626"),
            ("Taxi/Uber",    "expense", "🚕", "#F97316"),
            ("Flight",       "expense", "✈️", "#0EA5E9"),
            ("Train",        "expense", "🚆", "#8B5CF6"),
            ("Parking",      "expense", "🅿️", "#64748B"),
            // EXPENSE — Health
            ("Medicine",     "expense", "💊", "#EC4899"),
            ("Doctor",       "expense", "🩺", "#EF4444"),
            ("Gym",          "expense", "🏋️", "#F97316"),
            ("Salon",        "expense", "💅", "#DB2777"),
            // EXPENSE — Shopping
            ("Clothes",      "expense", "👗", "#A855F7"),
            ("Electronics",  "expense", "📱", "#3B82F6"),
            ("Games",        "expense", "🎮", "#6366F1"),
            ("Movies",       "expense", "🎬", "#EC4899"),
            ("Books",        "expense", "📖", "#10B981"),
            ("Music",        "expense", "🎵", "#8B5CF6"),
            ("Sport",        "expense", "⚽️", "#16A34A"),
            // EXPENSE — Life
            ("Education",    "expense", "🎓", "#2563EB"),
            ("Kids",         "expense", "🧸", "#F59E0B"),
            ("Pet",          "expense", "🐾", "#78716C"),
            ("Travel",       "expense", "🌍", "#0891B2"),
            ("Hotel",        "expense", "🏨", "#7C3AED"),
            ("Insurance",    "expense", "🛡️", "#64748B"),
            ("Tax",          "expense", "📋", "#374151"),
            ("Charity",      "expense", "❤️", "#EF4444"),
            ("Subscriptions","expense", "📺", "#6366F1"),
            ("Other",        "expense", "📌", "#9E9E9E"),
        ]
        for item in defaults {
            let cat   = CategoryEntity(context: context)
            cat.id    = UUID()
            cat.name  = item.0
            cat.type  = item.1
            cat.icon  = item.2
            cat.color = item.3
        }
        save()
        print("✅ \(defaults.count) default categories created")
    }

    // MARK: - Add Custom Category
    func addCustomCategory(
        name: String, type: String,
        icon: String, color: String
    ) -> CategoryEntity {
        let cat   = CategoryEntity(context: context)
        cat.id    = UUID()
        cat.name  = name
        cat.type  = type
        cat.icon  = icon
        cat.color = color
        save()
        return cat
    }

    // MARK: - Delete Category
    func deleteCategory(_ cat: CategoryEntity) {
        context.delete(cat)
        save()
    }

    // MARK: - Refresh Default Categories
    func refreshDefaultCategories() {
        // ✅ Delete individually for CloudKit tracking
        let req: NSFetchRequest<CategoryEntity>
            = CategoryEntity.fetchRequest()
        if let cats = try? context.fetch(req) {
            cats.forEach { context.delete($0) }
        }
        save()
        print("🗑️ Old categories cleared")
        addDefaultCategories()
        print("✅ Fresh categories added")
    }

    // MARK: - Category Usage (for frequent sort)
    func fetchCategoryUsage(type: String) -> [String: Int] {
        let req: NSFetchRequest<TransactionEntity>
            = TransactionEntity.fetchRequest()
        req.predicate = NSPredicate(
            format: "type == %@", type
        )
        let txs = (try? context.fetch(req)) ?? []
        var usage: [String: Int] = [:]
        for tx in txs {
            usage[tx.category ?? "Other", default: 0] += 1
        }
        return usage
    }


    func fetchCategories(type: String) -> [CategoryEntity] {
        let request: NSFetchRequest<CategoryEntity>
            = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "type == %@", type
        )
        do {
            let all  = try context.fetch(request)
            // ✅ Always deduplicate — keep first occurrence
            var seen = Set<String>()
            return all.filter {
                let name = $0.name ?? ""
                if seen.contains(name) { return false }
                seen.insert(name)
                return true
            }
        } catch {
            return []
        }
    }

    // MARK: - Deduplicate Categories in DB
    func deduplicateCategories() {
        let types = ["income", "expense"]
        for type in types {
            let request: NSFetchRequest<CategoryEntity>
                = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "type == %@", type
            )
            guard let all = try? context.fetch(request)
            else { continue }

            var seen = Set<String>()
            for cat in all {
                let name = cat.name ?? ""
                if seen.contains(name) {
                    context.delete(cat)
                } else {
                    seen.insert(name)
                }
            }
        }
        save()
        print("✅ Categories deduplicated")
    }

    func categoriesExist() -> Bool {
        let request: NSFetchRequest<CategoryEntity>
            = CategoryEntity.fetchRequest()
        request.fetchLimit = 1
        do {
            return try context.fetch(request).count > 0
        } catch {
            return false
        }
    }

    // MARK: ─────────────────────────────────────
    // ✅ Public wrapper for EditTransactionView
    func smartUpdateSummaryPublic(
        for date: Date, newType: String, newAmount: Double
    ) {
        smartUpdateSummary(
            for: date, newType: newType, newAmount: newAmount
        )
    }

    // MARK: DEDUPLICATE
    func deduplicateSummaries() {
        let all = fetchAllSummaries()
        var seen: [String: DailySummaryEntity] = [:]
        var duplicates: [DailySummaryEntity]   = []

        for summary in all {
            let dateKey = summary.date ?? ""
            let userKey = (summary.userId ?? "").uppercased()
            let key     = "\(dateKey)_\(userKey)"

            if let existing = seen[key] {
                // Keep synced, delete unsynced duplicate
                if existing.isSynced && !summary.isSynced {
                    duplicates.append(summary)
                } else if !existing.isSynced && summary.isSynced {
                    duplicates.append(existing)
                    seen[key] = summary
                } else {
                    duplicates.append(summary)
                }
            } else {
                seen[key] = summary
            }
        }

        if !duplicates.isEmpty {
            print("🧹 Removing \(duplicates.count) duplicate summaries")
            duplicates.forEach { context.delete($0) }
            save()
            print("✅ Dedup done. Remaining: \(seen.count)")
        } else {
            print("✅ No duplicates found")
        }
    }

    // MARK: NUCLEAR CLEAR
    // ─────────────────────────────────────────

    func clearAllLocalData() {
        let ctx = persistentContainer.viewContext

        // ✅ ONLY delete summaries and categories on logout
        // DO NOT delete transactions — they live in iCloud
        // Deleting transactions = data loss if iCloud hasn't synced yet
        // Summaries are safe to delete — Supabase restores them on login
        // Categories are safe to delete — defaults re-added on login

        // Delete summaries only
        let sumReq: NSFetchRequest<DailySummaryEntity>
            = DailySummaryEntity.fetchRequest()
        if let sums = try? ctx.fetch(sumReq) {
            sums.forEach { ctx.delete($0) }
            print("🗑️ Deleting \(sums.count) summaries")
        }

        // Delete categories (re-added on login)
        let catReq: NSFetchRequest<CategoryEntity>
            = CategoryEntity.fetchRequest()
        if let cats = try? ctx.fetch(catReq) {
            cats.forEach { ctx.delete($0) }
            print("🗑️ Deleting \(cats.count) categories")
        }

        // ✅ Keep transactions! iCloud manages them.
        // On login with different user → transactions filtered by userId
        // On login with same user → transactions already there ✅
        let txReq: NSFetchRequest<TransactionEntity>
            = TransactionEntity.fetchRequest()
        let txCount = (try? ctx.fetch(txReq))?.count ?? 0
        print("✅ Keeping \(txCount) transactions (iCloud managed)")

        do {
            try ctx.save()
            print("✅ Local data cleared (transactions preserved)")
        } catch {
            print("❌ Clear failed: \(error)")
        }
    }
}
