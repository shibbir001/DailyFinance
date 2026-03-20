// Controllers/HistoryController.swift
import Foundation
import Combine

class HistoryController: ObservableObject {

    // MARK: - Singleton
    static let shared = HistoryController()

    // MARK: - Published Properties
    @Published var monthTransactions: [TransactionEntity] = []
    @Published var monthlySummary:    MonthlySummary?     = nil
    @Published var selectedMonth:     Int = Calendar.current
        .component(.month, from: Date())
    @Published var selectedYear:      Int = Calendar.current
        .component(.year, from: Date())
    @Published var selectedFilter:    String = "all"
    @Published var searchText:        String = ""
    // ✅ Calendar data stored here so it persists
    // even when MonthCalendarView sheet is closed
    @Published var calendarDailyData:
        [String: (income: Double, expense: Double)] = [:]

    private let coreData     = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadMonthData()
        observeFilters()
        observeICloudChanges()
    }

    // MARK: - Observe iCloud Changes
    private func observeICloudChanges() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("iCloudDataChanged"),
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            print("☁️ History refreshing from iCloud")
            // ✅ Reload calendar data too
            self?.loadCalendarData()
            self?.loadMonthData()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataRestored"),
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            print("📥 History refreshing after restore")
            self?.loadCalendarData()
            self?.loadMonthData()
        }
    }

    // MARK: - Observe Filter Changes
    private func observeFilters() {
        $selectedMonth
            .combineLatest($selectedYear, $selectedFilter)
            .debounce(
                for: .milliseconds(100),
                scheduler: RunLoop.main
            )
            .sink { [weak self] _, _, _ in
                self?.loadMonthData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Month Data
    func loadMonthData() {
        // ✅ Also refresh calendar data
        loadCalendarData()

        // ── Step 1: Load transactions (for list view) ──
        let all = coreData.fetchTransactions(
            month: selectedMonth,
            year:  selectedYear
        )

        // Apply filter
        var filtered = all
        switch selectedFilter {
        case "income":
            filtered = all.filter { $0.type == "income" }
        case "expense":
            filtered = all.filter { $0.type == "expense" }
        default:
            filtered = all
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                ($0.note ?? "").lowercased()
                    .contains(searchText.lowercased())
                || ($0.category ?? "").lowercased()
                    .contains(searchText.lowercased())
            }
        }
        monthTransactions = filtered

        // ── Step 2: Calculate monthly summary ──────────
        // ✅ Use DailySummaryEntity for correct totals
        // This works even when individual transactions
        // are not restored (only summaries from cloud)
        calculateMonthlySummaryFromSummaries()
    }

    // MARK: - Calculate from DailySummaryEntity
    // ✅ Uses synced daily summaries — always correct!
    private func calculateMonthlySummaryFromSummaries() {

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var components       = DateComponents()
        components.year      = selectedYear
        components.month     = selectedMonth
        components.day       = 1
        let monthDate = Calendar.current
            .date(from: components) ?? Date()
        let monthKey  = formatter.string(from: monthDate)

        // Fetch all daily summaries for this month
        let allSummaries = coreData.fetchAllSummaries()
        let monthSummaries = allSummaries.filter { s in
            guard let dateStr = s.date else { return false }
            return dateStr.hasPrefix(monthKey)
        }

        // ✅ Sum from DailySummaryEntity (synced data)
        let totalIncome  = monthSummaries
            .reduce(0) { $0 + $1.totalIncome }
        let totalExpense = monthSummaries
            .reduce(0) { $0 + $1.totalExpense }
        let netBalance   = totalIncome - totalExpense

        // If we have summary data use it
        // Otherwise fall back to transactions
        if !monthSummaries.isEmpty {
            buildMonthlySummary(
                totalIncome:  totalIncome,
                totalExpense: totalExpense,
                netBalance:   netBalance,
                fromSummaries: monthSummaries
            )
        } else {
            // No summaries — use transactions
            calculateMonthlySummaryFromTransactions()
        }
    }

    // MARK: - Build Monthly Summary from Summaries
    private func buildMonthlySummary(
        totalIncome:   Double,
        totalExpense:  Double,
        netBalance:    Double,
        fromSummaries: [DailySummaryEntity]
    ) {
        // For category breakdown use transactions
        // (only available on device)
        let all = coreData.fetchTransactions(
            month: selectedMonth,
            year:  selectedYear
        )

        let expenseByCategory = Dictionary(
            grouping: all.filter { $0.type == "expense" }
        ) { $0.category ?? "Other" }
        .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let incomeByCategory = Dictionary(
            grouping: all.filter { $0.type == "income" }
        ) { $0.category ?? "Other" }
        .mapValues { $0.reduce(0) { $0 + $1.amount } }

        monthlySummary = MonthlySummary(
            month:             selectedMonth,
            year:              selectedYear,
            totalIncome:       totalIncome,
            totalExpense:      totalExpense,
            netBalance:        netBalance,
            // ✅ Count days that have data
            transactionCount:  fromSummaries.count,
            expenseByCategory: expenseByCategory,
            incomeByCategory:  incomeByCategory
        )
    }

    // MARK: - Fallback: Calculate from Transactions
    private func calculateMonthlySummaryFromTransactions() {
        let all = coreData.fetchTransactions(
            month: selectedMonth,
            year:  selectedYear
        )

        let totalIncome  = all
            .filter  { $0.type == "income" }
            .reduce(0) { $0 + $1.amount }
        let totalExpense = all
            .filter  { $0.type == "expense" }
            .reduce(0) { $0 + $1.amount }

        let expenseByCategory = Dictionary(
            grouping: all.filter { $0.type == "expense" }
        ) { $0.category ?? "Other" }
        .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let incomeByCategory = Dictionary(
            grouping: all.filter { $0.type == "income" }
        ) { $0.category ?? "Other" }
        .mapValues { $0.reduce(0) { $0 + $1.amount } }

        monthlySummary = MonthlySummary(
            month:             selectedMonth,
            year:              selectedYear,
            totalIncome:       totalIncome,
            totalExpense:      totalExpense,
            netBalance:        totalIncome - totalExpense,
            transactionCount:  all.count,
            expenseByCategory: expenseByCategory,
            incomeByCategory:  incomeByCategory
        )
    }

    // Debounce timer for calendar data
    private var calendarDebounceTimer: Timer?

    // MARK: - Load Calendar Data
    func loadCalendarData() {
        // ✅ Debounce — wait 0.3s to batch rapid calls
        calendarDebounceTimer?.invalidate()
        calendarDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: false
        ) { [weak self] _ in
            self?.doLoadCalendarData()
        }
    }

    private func doLoadCalendarData() {
        var data: [String: (income: Double, expense: Double)] = [:]

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var components       = DateComponents()
        components.year      = selectedYear
        components.month     = selectedMonth
        components.day       = 1
        let monthDate = Calendar.current
            .date(from: components) ?? Date()
        let monthKey  = formatter.string(from: monthDate)

        let allSummaries = coreData.fetchAllSummaries()
        let monthSummaries = allSummaries.filter {
            $0.date?.hasPrefix(monthKey) == true
        }

        for summary in monthSummaries {
            guard let dateStr = summary.date else { continue }
            data[dateStr] = (
                income:  summary.totalIncome,
                expense: summary.totalExpense
            )
        }

        DispatchQueue.main.async {
            self.calendarDailyData = data
        }
        print("📅 Controller: loaded \(data.count) days for calendar")
    }

    // MARK: - Navigate Months
    func goToPreviousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
    }

    func goToNextMonth() {
        let now          = Date()
        let currentMonth = Calendar.current
            .component(.month, from: now)
        let currentYear  = Calendar.current
            .component(.year,  from: now)

        if selectedYear < currentYear
            || (selectedYear == currentYear
                && selectedMonth < currentMonth) {
            if selectedMonth == 12 {
                selectedMonth = 1
                selectedYear += 1
            } else {
                selectedMonth += 1
            }
        }
    }

    var canGoNext: Bool {
        let now          = Date()
        let currentMonth = Calendar.current
            .component(.month, from: now)
        let currentYear  = Calendar.current
            .component(.year,  from: now)
        return !(selectedYear == currentYear
            && selectedMonth == currentMonth)
    }

    var monthName: String {
        let f        = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        var c        = DateComponents()
        c.month      = selectedMonth
        c.year       = selectedYear
        c.day        = 1
        let date = Calendar.current
            .date(from: c) ?? Date()
        return f.string(from: date)
    }
}

// MARK: - Monthly Summary Model
struct MonthlySummary {
    var month:             Int
    var year:              Int
    var totalIncome:       Double
    var totalExpense:      Double
    var netBalance:        Double
    var transactionCount:  Int
    var expenseByCategory: [String: Double]
    var incomeByCategory:  [String: Double]

    var isProfit: Bool { netBalance >= 0 }

    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netBalance / totalIncome) * 100
    }

    var topExpenseCategory: String {
        expenseByCategory
            .max(by: { $0.value < $1.value })?.key
            ?? "None"
    }
}
