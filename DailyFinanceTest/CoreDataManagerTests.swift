//
//  CoreDataManagerTests.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//


// DailyFinanceTests/CoreDataManagerTests.swift
import XCTest
import CoreData
@testable import DailyFinance

class CoreDataManagerTests: XCTestCase {

    // MARK: - Properties
    var coreData: CoreDataManager!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        coreData = CoreDataManager.shared
        clearAllData()  // fresh start each test
    }

    override func tearDown() {
        clearAllData()
        super.tearDown()
    }

    // MARK: - Helper: Clear All Data
    func clearAllData() {
        let context = coreData.context

        // Delete all transactions
        let txRequest: NSFetchRequest<NSFetchRequestResult>
            = TransactionEntity.fetchRequest()
        let txDelete = NSBatchDeleteRequest(
            fetchRequest: txRequest)
        try? context.execute(txDelete)

        // Delete all summaries
        let sumRequest: NSFetchRequest<NSFetchRequestResult>
            = DailySummaryEntity.fetchRequest()
        let sumDelete = NSBatchDeleteRequest(
            fetchRequest: sumRequest)
        try? context.execute(sumDelete)

        context.reset()
    }

    // MARK: - Test 1: Add Transaction
    func test_addTransaction_savesCorrectly() {
        // Given
        let amount   = 100.0
        let type     = "expense"
        let category = "Food"
        let note     = "Test lunch"
        let date     = Date()

        // When
        let transaction = coreData.addTransaction(
            type:     type,
            amount:   amount,
            category: category,
            note:     note,
            date:     date
        )

        // Then
        XCTAssertNotNil(transaction.id)
        XCTAssertEqual(transaction.amount,   amount)
        XCTAssertEqual(transaction.type,     type)
        XCTAssertEqual(transaction.category, category)
        XCTAssertEqual(transaction.note,     note)
        XCTAssertFalse(transaction.isSynced) // not synced yet
        print("✅ test_addTransaction_savesCorrectly passed")
    }

    // MARK: - Test 2: Fetch Transactions by Date
    func test_fetchTransactions_byDate_returnsCorrect() {
        // Given
        let today     = Date()
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: today
        )!

        // Add today's transaction
        coreData.addTransaction(
            type: "expense", amount: 50,
            category: "Food", note: "Today",
            date: today
        )

        // Add yesterday's transaction
        coreData.addTransaction(
            type: "income", amount: 500,
            category: "Salary", note: "Yesterday",
            date: yesterday
        )

        // When
        let todayResults     = coreData
            .fetchTransactions(for: today)
        let yesterdayResults = coreData
            .fetchTransactions(for: yesterday)

        // Then
        XCTAssertEqual(todayResults.count,     1)
        XCTAssertEqual(yesterdayResults.count, 1)
        XCTAssertEqual(todayResults.first?.note,     "Today")
        XCTAssertEqual(yesterdayResults.first?.note, "Yesterday")
        print("✅ test_fetchTransactions_byDate passed")
    }

    // MARK: - Test 3: Daily Summary Auto Updates
    func test_dailySummary_updatesAfterTransaction() {
        // Given
        let today     = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)

        // When - add income
        coreData.addTransaction(
            type: "income", amount: 500,
            category: "Salary", note: "Test",
            date: today
        )

        // Add expense
        coreData.addTransaction(
            type: "expense", amount: 150,
            category: "Food", note: "Test",
            date: today
        )

        // Then
        let summary = coreData
            .fetchDailySummary(for: dateString)

        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalIncome,  500)
        XCTAssertEqual(summary?.totalExpense, 150)
        XCTAssertEqual(summary?.netBalance,   350)
        print("✅ test_dailySummary_updatesAfterTransaction passed")
    }

    // MARK: - Test 4: Delete Transaction
    func test_deleteTransaction_removesFromCoreData() {
        // Given
        let transaction = coreData.addTransaction(
            type: "expense", amount: 50,
            category: "Food", note: "Delete me",
            date: Date()
        )

        // When
        coreData.deleteTransaction(transaction)

        // Then
        let results = coreData.fetchTransactions(for: Date())
        XCTAssertTrue(results.isEmpty)
        print("✅ test_deleteTransaction passed")
    }

    // MARK: - Test 5: Daily Summary Recalculates After Delete
    func test_summary_recalculates_afterDelete() {
        // Given
        let today  = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)

        coreData.addTransaction(
            type: "income", amount: 500,
            category: "Salary", note: "Keep",
            date: today
        )
        let toDelete = coreData.addTransaction(
            type: "expense", amount: 100,
            category: "Food", note: "Delete",
            date: today
        )

        // When
        coreData.deleteTransaction(toDelete)

        // Then
        let summary = coreData
            .fetchDailySummary(for: dateString)
        XCTAssertEqual(summary?.totalExpense, 0)
        XCTAssertEqual(summary?.netBalance,   500)
        print("✅ test_summary_recalculates_afterDelete passed")
    }

    // MARK: - Test 6: Fetch Month Transactions
    func test_fetchMonthTransactions_returnsCorrect() {
        // Given
        let calendar     = Calendar.current
        let currentMonth = calendar.component(.month,
            from: Date())
        let currentYear  = calendar.component(.year,
            from: Date())

        // Add 3 transactions this month
        for i in 1...3 {
            var components   = DateComponents()
            components.year  = currentYear
            components.month = currentMonth
            components.day   = i
            let date = calendar.date(from: components)!

            coreData.addTransaction(
                type: "expense", amount: Double(i * 10),
                category: "Food", note: "Test \(i)",
                date: date
            )
        }

        // When
        let results = coreData.fetchTransactions(
            month: currentMonth,
            year:  currentYear
        )

        // Then
        XCTAssertEqual(results.count, 3)
        print("✅ test_fetchMonthTransactions passed")
    }

    // MARK: - Test 7: isDataEmpty Check
    func test_isDataEmpty_returnsTrue_whenNoData() {
        // Given - data already cleared in setUp
        // When
        let isEmpty = coreData.isDataEmpty()
        // Then
        XCTAssertTrue(isEmpty)
        print("✅ test_isDataEmpty_true passed")
    }

    func test_isDataEmpty_returnsFalse_whenDataExists() {
        // Given
        coreData.addTransaction(
            type: "expense", amount: 10,
            category: "Food", note: "Test",
            date: Date()
        )

        // When
        let isEmpty = coreData.isDataEmpty()

        // Then
        XCTAssertFalse(isEmpty)
        print("✅ test_isDataEmpty_false passed")
    }

    // MARK: - Test 8: Default Categories
    func test_defaultCategories_areAdded() {
        // Given - clear categories first
        let catRequest: NSFetchRequest<NSFetchRequestResult>
            = CategoryEntity.fetchRequest()
        let catDelete = NSBatchDeleteRequest(
            fetchRequest: catRequest)
        try? coreData.context.execute(catDelete)

        // When
        coreData.addDefaultCategories()

        // Then
        let income  = coreData.fetchCategories(type: "income")
        let expense = coreData.fetchCategories(type: "expense")

        XCTAssertGreaterThan(income.count,  0)
        XCTAssertGreaterThan(expense.count, 0)
        print("✅ test_defaultCategories passed")
    }

    // MARK: - Test 9: isSynced Flag
    func test_markAsSynced_updatesSyncedFlag() {
        // Given
        coreData.addTransaction(
            type: "expense", amount: 50,
            category: "Food", note: "Test",
            date: Date()
        )

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString       = formatter.string(from: Date())

        guard let summary = coreData
            .fetchDailySummary(for: dateString)
        else {
            XCTFail("Summary not found")
            return
        }

        // Verify not synced
        XCTAssertFalse(summary.isSynced)

        // When
        coreData.markAsSynced(summary)

        // Then
        XCTAssertTrue(summary.isSynced)
        print("✅ test_markAsSynced passed")
    }

    // MARK: - Test 10: Unsynced Summaries
    func test_fetchUnsyncedSummaries_returnsUnsynced() {
        // Given - add transaction (creates unsynced summary)
        coreData.addTransaction(
            type: "expense", amount: 50,
            category: "Food", note: "Test",
            date: Date()
        )

        // When
        let unsynced = coreData.fetchUnsyncedSummaries()

        // Then
        XCTAssertGreaterThan(unsynced.count, 0)
        print("✅ test_fetchUnsyncedSummaries passed")
    }
}