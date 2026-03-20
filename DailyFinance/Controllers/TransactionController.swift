// Controllers/TransactionController.swift
import Foundation
import Combine
internal import CoreData

class TransactionController: ObservableObject {

    // MARK: - Singleton
    static let shared = TransactionController()

    // MARK: - Published Properties
    @Published var todayTransactions: [TransactionEntity] = []
    @Published var todaySummary:      DailySummaryEntity? = nil

    // ✅ Store VALUES not object references
    // SwiftUI detects changes to value types ✅
    // but NOT changes to reference type properties ❌
    @Published var todayIncomeAmount:  Double = 0
    @Published var todayExpenseAmount: Double = 0
    @Published var todayBalanceAmount: Double = 0

    @Published var incomeCategories:  [CategoryEntity]   = []
    @Published var expenseCategories: [CategoryEntity]   = []
    @Published var isLoading:         Bool               = false

    private let coreData = CoreDataManager.shared

    private init() {
        loadTodayData()
        loadCategories()
    }

    // MARK: - Load Today
    func loadTodayData() {
        let today = Date()

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone   = TimeZone.current
        let dateString       = formatter.string(from: today)

        // ✅ Refresh individual objects instead of full reset
        // Safer than context.reset() — doesn't lose pending changes
        coreData.context.registeredObjects.forEach {
            coreData.context.refresh($0, mergeChanges: true)
        }

        let txs     = coreData.fetchTransactions(for: today)
        let summary = coreData.fetchDailySummary(for: dateString)

        let income  = summary?.totalIncome  ?? 0
        let expense = summary?.totalExpense ?? 0
        let balance = income - expense

        // ✅ Always update on main thread
        DispatchQueue.main.async {
            self.todayTransactions   = txs
            self.todaySummary        = summary
            // ✅ Update VALUE types — these trigger SwiftUI re-render
            self.todayIncomeAmount   = income
            self.todayExpenseAmount  = expense
            self.todayBalanceAmount  = balance
            print("🔄 loadTodayData: \(txs.count) txs, income=\(income) expense=\(expense)")
        }
    }

    // MARK: - Load Categories
    func loadCategories() {
        incomeCategories  = coreData.fetchCategories(type: "income")
        expenseCategories = coreData.fetchCategories(type: "expense")
    }

    // MARK: - Add Transaction
    func addTransaction(
        type:     String,
        amount:   Double,
        category: String,
        note:     String
    ) {
        _ = coreData.addTransaction(
            type:     type,
            amount:   amount,
            category: category,
            note:     note,
            date:     Date()
        )
        loadTodayData()

        // ✅ Sync summaries only (transactions via iCloud)
        if NetworkMonitor.shared.isConnected {
            Task {
                await SyncService.shared.syncTodayData()
            }
        }
    }

    // MARK: - Delete Transaction
    func deleteTransaction(_ tx: TransactionEntity) {
        coreData.deleteTransactionSmart(tx)
        loadTodayData()

        if NetworkMonitor.shared.isConnected {
            Task {
                await SyncService.shared.syncTodayData()
            }
        }
    }

    // MARK: - Fetch for Date
    func fetchTransactions(for date: Date) -> [TransactionEntity] {
        return coreData.fetchTransactions(for: date)
    }

    // MARK: - Fetch Month
    func fetchMonthTransactions(
        month: Int, year: Int
    ) -> [TransactionEntity] {
        return coreData.fetchTransactions(month: month, year: year)
    }

    // MARK: - Computed
    // ✅ Use @Published value types for reliable SwiftUI updates
    var todayIncome: Double  { todayIncomeAmount }
    var todayExpense: Double { todayExpenseAmount }
    var todayBalance: Double { todayBalanceAmount }
    var isProfit: Bool       { todayBalanceAmount >= 0 }
}
