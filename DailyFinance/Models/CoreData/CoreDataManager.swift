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
    static let iCloudEnabledAtLaunch: Bool = {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }()

    var isICloudEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled")
            print(newValue
                  ? "☁️ iCloud will enable on next launch"
                  : "💾 iCloud will disable on next launch")
        }
    }

    // MARK: - App Group (Widget Support)
    // ✅ Widget reads the same SQLite file via this shared URL
    static let appGroupID = "group.shibbir.DailyFinance"

    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("DailyFinance.sqlite")
    }

    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        buildContainer(useICloud: CoreDataManager.iCloudEnabledAtLaunch)
    }()

    // MARK: - Build Container
    private func buildContainer(useICloud: Bool) -> NSPersistentContainer {
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
        let container = NSPersistentCloudKitContainer(name: "DailyFinance")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No store description found")
        }

        // ✅ Use App Group URL so widget reads the same store
        if let storeURL = CoreDataManager.sharedStoreURL {
            description.url = storeURL
            print("☁️ CloudKit store URL: \(storeURL.lastPathComponent)")
        }

        // ✅ Set CloudKit container identifier
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.shibbir-Daily-Finance"
            )

        // ✅ Required for CloudKit sync
        description.setOption(true as NSNumber,
                               forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // ✅ Migration
        description.setOption(true as NSNumber,
                               forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber,
                               forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { desc, error in
            if let error = error {
                print("❌ CloudKit store failed: \(error)")
                DispatchQueue.main.async { self.handleCloudKitError(error) }
            } else {
                print("✅ CloudKit store loaded: \(desc.url?.lastPathComponent ?? "")")
                DispatchQueue.main.async { self.iCloudError = nil }
            }
        }
        
        // Temporary — remove after testing
        container.viewContext.refreshAllObjects()
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // ✅ Listen for remote changes with debounce
        var debounceTimer: Timer?
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object:  container.persistentStoreCoordinator,
            queue:   .main
        ) { _ in
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: 1.5, repeats: false
            ) { _ in
                print("☁️ iCloud sync complete — refreshing UI")
                DispatchQueue.main.async {
                    TransactionController.shared.loadTodayData()
                    HistoryController.shared.loadCalendarData()
                    HistoryController.shared.loadMonthData()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("iCloudDataChanged"),
                        object: nil
                    )
                }
                for delay in [3.0, 10.0, 30.0, 60.0, 120.0, 180.0, 300.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let req: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                        let total      = (try? CoreDataManager.shared.context.fetch(req))?.count ?? 0
                        let todayCount = CoreDataManager.shared.fetchTransactions(for: Date()).count
                        print("🔄 iCloud poll (\(Int(delay))s): total=\(total) today=\(todayCount)")
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

        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { _ in
            print("☁️ iCloud account changed")
            self.checkCloudKitStatus()
        }

        print("✅ CloudKit container ready")
        return container
    }

    // MARK: - Handle CloudKit Errors
    private func handleCloudKitError(_ error: Error) {
        let nsError   = error as NSError
        let errorCode = nsError.code
        print("🔍 CloudKit error code: \(errorCode)")
        print("   Domain: \(nsError.domain)")

        switch errorCode {
        case 22: print("❌ iCloud storage is FULL");        iCloudError = .storageFull
        case 9:  print("❌ iCloud account not available");  iCloudError = .accountNotAvailable
        case 4:  print("❌ Network unavailable");           iCloudError = .networkUnavailable
        default:
            print("⚠️ CloudKit error \(errorCode): \(error.localizedDescription)")
            if nsError.domain == "NSCocoaErrorDomain" && errorCode == 134060 { return }
            iCloudError = .unknown(error.localizedDescription)
        }
        print("ℹ️ App continues working locally")
    }

    // MARK: - Check CloudKit Account Status
    func checkCloudKitStatus() {
        CKContainer(identifier: "iCloud.shibbir-Daily-Finance")
            .accountStatus { status, _ in
                DispatchQueue.main.async {
                    switch status {
                    case .available:   self.iCloudError = nil
                    case .noAccount:   self.iCloudError = .accountNotAvailable
                    case .restricted:  self.iCloudError = .accountNotAvailable
                    default:           break
                    }
                }
            }
    }

    // MARK: - Local Container
    private func buildLocalContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "DailyFinance")

        // ✅ Use App Group URL so widget reads the same store
        if let storeURL = CoreDataManager.sharedStoreURL {
            let desc = NSPersistentStoreDescription(url: storeURL)
            desc.setOption(true as NSNumber,
                           forKey: NSMigratePersistentStoresAutomaticallyOption)
            desc.setOption(true as NSNumber,
                           forKey: NSInferMappingModelAutomaticallyOption)
            container.persistentStoreDescriptions = [desc]
            print("💾 Local store URL: \(storeURL.lastPathComponent)")
        } else {
            container.persistentStoreDescriptions.first?.setOption(
                true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            container.persistentStoreDescriptions.first?.setOption(
                true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error = error { print("❌ Local store failed: \(error)") }
        }

        print("✅ Local container ready")
        return container
    }

    var context: NSManagedObjectContext { persistentContainer.viewContext }

    private init() {}

    // MARK: - Save Context
    func save() {
        if context.hasChanges {
            do { try context.save() }
            catch { print("Save error: \(error)") }
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: TRANSACTION OPERATIONS
    // ─────────────────────────────────────────

    @discardableResult
    func addTransaction(
        type: String, amount: Double,
        category: String, note: String, date: Date
    ) -> TransactionEntity {

        let newId       = UUID()
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
            return recentCheck.first { $0.amount == amount && $0.type == type }
                ?? TransactionEntity(context: context)
        }

        let tx      = TransactionEntity(context: context)
        tx.id       = newId
        tx.type     = type
        tx.amount   = amount
        tx.category = category
        tx.note     = note.isEmpty ? category : note
        tx.date     = date
        tx.isSynced = false
        tx.userId   = currentUserId.isEmpty ? nil : currentUserId.uppercased()
        save()

        smartUpdateSummary(for: date, newType: type, newAmount: amount)
        print("✅ Transaction saved: \(type) \(amount) on \(date)")
        return tx
    }

    func deleteTransactionSmart(_ tx: TransactionEntity) {
        let date      = tx.date   ?? Date()
        let type      = tx.type   ?? "expense"
        let amount    = tx.amount
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        context.delete(tx)
        save()

        if let summary = fetchDailySummary(for: dateString) {
            if type == "income" {
                summary.totalIncome  = max(0, summary.totalIncome  - amount)
            } else {
                summary.totalExpense = max(0, summary.totalExpense - amount)
            }
            summary.netBalance = summary.totalIncome - summary.totalExpense
            summary.isSynced   = false
            save()
            print("✅ Subtracted from summary: \(dateString)")
            print("   income=\(summary.totalIncome) expense=\(summary.totalExpense)")
        }
    }

    private func smartUpdateSummary(for date: Date, newType: String, newAmount: Double) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone   = TimeZone.current
        let dateString = formatter.string(from: date)

        if let existing = fetchDailySummary(for: dateString) {
            if newType == "income" { existing.totalIncome  += newAmount }
            else                   { existing.totalExpense += newAmount }
            existing.netBalance = existing.totalIncome - existing.totalExpense
            existing.isSynced   = false
            existing.userId     = currentUserId.isEmpty ? existing.userId : currentUserId
            save()
            print("✅ Added to existing summary: \(dateString)")
            print("   income=\(existing.totalIncome) expense=\(existing.totalExpense)")
        } else {
            let summary           = DailySummaryEntity(context: context)
            summary.id            = UUID()
            summary.date          = dateString
            summary.totalIncome   = newType == "income"  ? newAmount : 0
            summary.totalExpense  = newType == "expense" ? newAmount : 0
            summary.netBalance    = newType == "income"  ? newAmount : -newAmount
            summary.isSynced      = false
            summary.userId        = currentUserId.isEmpty ? nil : currentUserId
            save()
            print("✅ New summary created: \(dateString)")
        }
    }

    func updateDailySummary(for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone   = TimeZone.current
        let dateString   = formatter.string(from: date)
        let transactions = fetchTransactions(for: date)

        if let existing = fetchDailySummary(for: dateString) {
            if !transactions.isEmpty {
                let income  = transactions.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount }
                let expense = transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
                existing.totalIncome  = income
                existing.totalExpense = expense
                existing.netBalance   = income - expense
                existing.isSynced     = false
                existing.userId       = currentUserId.isEmpty ? existing.userId : currentUserId
                save()
                print("✅ Summary recalculated: \(dateString)")
            } else {
                print("ℹ️ No local transactions for \(dateString) — keeping cloud summary")
            }
        } else if !transactions.isEmpty {
            let income  = transactions.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount }
            let expense = transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
            let summary           = DailySummaryEntity(context: context)
            summary.id            = UUID()
            summary.date          = dateString
            summary.totalIncome   = income
            summary.totalExpense  = expense
            summary.netBalance    = income - expense
            summary.isSynced      = false
            summary.userId        = currentUserId.isEmpty ? nil : currentUserId
            save()
        }
    }

    // MARK: ─────────────────────────────────────
    // MARK: FETCH OPERATIONS
    // ─────────────────────────────────────────

    func fetchTransactions(for date: Date) -> [TransactionEntity] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        let calendar = Calendar.current
        let start    = calendar.startOfDay(for: date)
        let end      = calendar.date(byAdding: .day, value: 1, to: start)!

        if currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                start as CVarArg, end as CVarArg)
        } else {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND userId ==[c] %@",
                start as CVarArg, end as CVarArg, currentUserId)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchTransactions(month: Int, year: Int) -> [TransactionEntity] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        var components  = DateComponents()
        components.year = year; components.month = month; components.day = 1
        let calendar    = Calendar.current
        let startDate   = calendar.date(from: components)!
        let endDate     = calendar.date(byAdding: .month, value: 1, to: startDate)!

        if currentUserId.isEmpty {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startDate as CVarArg, endDate as CVarArg)
        } else {
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND (userId ==[c] %@ OR userId == nil OR userId == '')",
                startDate as CVarArg, endDate as CVarArg, currentUserId)
        }
        return (try? context.fetch(request)) ?? []
    }

    func fetchDailySummary(for dateString: String) -> DailySummaryEntity? {
        let request: NSFetchRequest<DailySummaryEntity> = DailySummaryEntity.fetchRequest()
        request.predicate  = NSPredicate(format: "date == %@", dateString)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func fetchDailySummary(for date: Date) -> DailySummaryEntity? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone   = TimeZone.current
        return fetchDailySummary(for: fmt.string(from: date))
    }

    func fetchAllSummaries() -> [DailySummaryEntity] {
        let request: NSFetchRequest<DailySummaryEntity> = DailySummaryEntity.fetchRequest()
        if !currentUserId.isEmpty {
            request.predicate = NSPredicate(format: "userId ==[c] %@", currentUserId)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchUnsyncedSummaries() -> [DailySummaryEntity] {
        let request: NSFetchRequest<DailySummaryEntity> = DailySummaryEntity.fetchRequest()
        if currentUserId.isEmpty {
            request.predicate = NSPredicate(format: "isSynced == false")
        } else {
            request.predicate = NSPredicate(
                format: "isSynced == false AND (userId == %@ OR userId == nil OR userId == '')",
                currentUserId)
        }
        let results = (try? context.fetch(request)) ?? []
        print("🔍 fetchUnsyncedSummaries: found \(results.count) for userId=\(currentUserId.prefix(8))")
        return results
    }

    func fetchUnsyncedTransactions(userId: String) -> [TransactionEntity] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        if userId.isEmpty {
            request.predicate = NSPredicate(format: "isSynced == false")
        } else {
            request.predicate = NSPredicate(
                format: "isSynced == false AND (userId ==[c] %@ OR userId == nil OR userId == '')",
                userId)
        }
        return (try? context.fetch(request)) ?? []
    }

    func isDataEmpty() -> Bool { fetchAllSummaries().isEmpty }

    func markAsSynced(_ summary: DailySummaryEntity) {
        summary.isSynced = true
        save()
    }

    // MARK: ─────────────────────────────────────
    // MARK: CATEGORY OPERATIONS
    // ─────────────────────────────────────────

    func addDefaultCategories() {
        let defaults: [(String, String, String, String)] = [
            ("Salary",        "income",  "🏦", "#22C55E"),
            ("Freelance",     "income",  "🎯", "#10B981"),
            ("Business",      "income",  "🚀", "#059669"),
            ("Investment",    "income",  "📊", "#0D9488"),
            ("Rental",        "income",  "🏡", "#0891B2"),
            ("Gift",          "income",  "🎁", "#7C3AED"),
            ("Bonus",         "income",  "⭐️", "#D97706"),
            ("Refund",        "income",  "🔄", "#2563EB"),
            ("Side Hustle",   "income",  "💡", "#DB2777"),
            ("Groceries",     "expense", "🛒", "#F97316"),
            ("Restaurant",    "expense", "🍽️", "#EF4444"),
            ("Coffee",        "expense", "☕️", "#92400E"),
            ("Alcohol",       "expense", "🍷", "#BE123C"),
            ("Rent",          "expense", "🏠", "#64748B"),
            ("Utilities",     "expense", "⚡️", "#F59E0B"),
            ("Internet",      "expense", "📡", "#3B82F6"),
            ("Furniture",     "expense", "🛋️", "#78716C"),
            ("Repairs",       "expense", "🔧", "#6B7280"),
            ("Fuel",          "expense", "⛽️", "#DC2626"),
            ("Taxi/Uber",     "expense", "🚕", "#F97316"),
            ("Flight",        "expense", "✈️", "#0EA5E9"),
            ("Train",         "expense", "🚆", "#8B5CF6"),
            ("Parking",       "expense", "🅿️", "#64748B"),
            ("Medicine",      "expense", "💊", "#EC4899"),
            ("Doctor",        "expense", "🩺", "#EF4444"),
            ("Gym",           "expense", "🏋️", "#F97316"),
            ("Salon",         "expense", "💅", "#DB2777"),
            ("Clothes",       "expense", "👗", "#A855F7"),
            ("Electronics",   "expense", "📱", "#3B82F6"),
            ("Games",         "expense", "🎮", "#6366F1"),
            ("Movies",        "expense", "🎬", "#EC4899"),
            ("Books",         "expense", "📖", "#10B981"),
            ("Music",         "expense", "🎵", "#8B5CF6"),
            ("Sport",         "expense", "⚽️", "#16A34A"),
            ("Education",     "expense", "🎓", "#2563EB"),
            ("Kids",          "expense", "🧸", "#F59E0B"),
            ("Pet",           "expense", "🐾", "#78716C"),
            ("Travel",        "expense", "🌍", "#0891B2"),
            ("Hotel",         "expense", "🏨", "#7C3AED"),
            ("Insurance",     "expense", "🛡️", "#64748B"),
            ("Tax",           "expense", "📋", "#374151"),
            ("Charity",       "expense", "❤️", "#EF4444"),
            ("Subscriptions", "expense", "📺", "#6366F1"),
            ("Other",         "expense", "📌", "#9E9E9E"),
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

    func addCustomCategory(name: String, type: String, icon: String, color: String) -> CategoryEntity {
        let cat = CategoryEntity(context: context)
        cat.id  = UUID(); cat.name = name; cat.type = type; cat.icon = icon; cat.color = color
        save()
        return cat
    }

    func deleteCategory(_ cat: CategoryEntity) { context.delete(cat); save() }

    func refreshDefaultCategories() {
        let req: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        if let cats = try? context.fetch(req) { cats.forEach { context.delete($0) } }
        save()
        print("🗑️ Old categories cleared")
        addDefaultCategories()
        print("✅ Fresh categories added")
    }

    func fetchCategoryUsage(type: String) -> [String: Int] {
        let req: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "type == %@", type)
        let txs = (try? context.fetch(req)) ?? []
        var usage: [String: Int] = [:]
        for tx in txs { usage[tx.category ?? "Other", default: 0] += 1 }
        return usage
    }

    func fetchCategories(type: String) -> [CategoryEntity] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type)
        guard let all = try? context.fetch(request) else { return [] }
        var seen = Set<String>()
        return all.filter {
            let name = $0.name ?? ""
            if seen.contains(name) { return false }
            seen.insert(name); return true
        }
    }

    func deduplicateCategories() {
        for type in ["income", "expense"] {
            let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "type == %@", type)
            guard let all = try? context.fetch(request) else { continue }
            var seen = Set<String>()
            for cat in all {
                let name = cat.name ?? ""
                if seen.contains(name) { context.delete(cat) } else { seen.insert(name) }
            }
        }
        save()
        print("✅ Categories deduplicated")
    }

    func categoriesExist() -> Bool {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.fetchLimit = 1
        return (try? context.fetch(request).count > 0) ?? false
    }

    // MARK: ─────────────────────────────────────
    func smartUpdateSummaryPublic(for date: Date, newType: String, newAmount: Double) {
        smartUpdateSummary(for: date, newType: newType, newAmount: newAmount)
    }

    // MARK: DEDUPLICATE SUMMARIES
    func deduplicateSummaries() {
        let all = fetchAllSummaries()
        var seen       = [String: DailySummaryEntity]()
        var duplicates = [DailySummaryEntity]()

        for summary in all {
            let key = "\(summary.date ?? "")_\((summary.userId ?? "").uppercased())"
            if let existing = seen[key] {
                if existing.isSynced && !summary.isSynced {
                    duplicates.append(summary)
                } else if !existing.isSynced && summary.isSynced {
                    duplicates.append(existing); seen[key] = summary
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

    // MARK: CLEAR LOCAL DATA
    func clearAllLocalData() {
        let ctx = persistentContainer.viewContext

        let sumReq: NSFetchRequest<DailySummaryEntity> = DailySummaryEntity.fetchRequest()
        if let sums = try? ctx.fetch(sumReq) {
            sums.forEach { ctx.delete($0) }
            print("🗑️ Deleting \(sums.count) summaries")
        }

        let catReq: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        if let cats = try? ctx.fetch(catReq) {
            cats.forEach { ctx.delete($0) }
            print("🗑️ Deleting \(cats.count) categories")
        }

        let txReq: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
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
