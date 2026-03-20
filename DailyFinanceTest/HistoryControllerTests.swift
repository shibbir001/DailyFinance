//
//  HistoryControllerTests.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//


// DailyFinanceTests/HistoryControllerTests.swift
import XCTest
@testable import DailyFinance

class HistoryControllerTests: XCTestCase {

    var controller: HistoryController!
    var coreData:   CoreDataManager!

    override func setUp() {
        super.setUp()
        coreData   = CoreDataManager.shared
        controller = HistoryController.shared
        addTestData()
    }

    override func tearDown() {
        clearData()
        super.tearDown()
    }

    // MARK: - Add Test Data
    func addTestData() {
        let calendar     = Calendar.current
        let currentMonth = calendar.component(
            .month, from: Date())
        let currentYear  = calendar.component(
            .year,  from: Date())

        // Add income
        var comp         = DateComponents()
        comp.year        = currentYear
        comp.month       = currentMonth
        comp.day         = 1
        let date1 = calendar.date(from: comp)!

        coreData.addTransaction(
            type: "income", amount: 2000,
            category: "Salary", note: "Monthly",
            date: date1
        )

        // Add expenses
        comp.day  = 2
        let date2 = calendar.date(from: comp)!
        coreData.addTransaction(
            type: "expense", amount: 300,
            category: "Food", note: "Groceries",
            date: date2
        )

        comp.day  = 3
        let date3 = calendar.date(from: comp)!
        coreData.addTransaction(
            type: "expense", amount: 500,
            category: "Rent", note: "Monthly rent",
            date: date3
        )

        controller.loadMonthData()
    }

    func clearData() {
        let context = coreData.context
        let txReq: NSFetchRequest<NSFetchRequestResult>
            = TransactionEntity.fetchRequest()
        try? context.execute(
            NSBatchDeleteRequest(fetchRequest: txReq))
        let sumReq: NSFetchRequest<NSFetchRequestResult>
            = DailySummaryEntity.fetchRequest()
        try? context.execute(
            NSBatchDeleteRequest(fetchRequest: sumReq))
        context.reset()
    }

    // MARK: - Test 1: Load Month Data
    func test_loadMonthData_returnsAllTransactions() {
        XCTAssertEqual(
            controller.monthTransactions.count, 3)
        print("✅ test_loadMonthData passed")
    }

    // MARK: - Test 2: Filter Income
    func test_filter_income_returnsOnlyIncome() {
        controller.selectedFilter = "income"
        controller.loadMonthData()

        XCTAssertTrue(controller.monthTransactions
            .allSatisfy { $0.type == "income" })
        print("✅ test_filter_income passed")
    }

    // MARK: - Test 3: Filter Expense
    func test_filter_expense_returnsOnlyExpenses() {
        controller.selectedFilter = "expense"
        controller.loadMonthData()

        XCTAssertTrue(controller.monthTransactions
            .allSatisfy { $0.type == "expense" })
        print("✅ test_filter_expense passed")
    }

    // MARK: - Test 4: Search Works
    func test_search_filtersByNote() {
        controller.selectedFilter = "all"
        controller.searchText     = "Groceries"
        controller.loadMonthData()

        XCTAssertEqual(
            controller.monthTransactions.count, 1)
        XCTAssertEqual(
            controller.monthTransactions.first?.note,
            "Groceries")
        print("✅ test_search_filtersByNote passed")
    }

    // MARK: - Test 5: Monthly Summary Correct
    func test_monthlySummary_calculatesCorrectly() {
        controller.selectedFilter = "all"
        controller.searchText     = ""
        controller.loadMonthData()

        XCTAssertEqual(
            controller.monthlySummary?.totalIncome,  2000)
        XCTAssertEqual(
            controller.monthlySummary?.totalExpense, 800)
        XCTAssertEqual(
            controller.monthlySummary?.netBalance,   1200)
        print("✅ test_monthlySummary_correct passed")
    }

    // MARK: - Test 6: Navigate to Previous Month
    func test_goToPreviousMonth_decrementsMonth() {
        let original = controller.selectedMonth

        controller.goToPreviousMonth()

        let expected = original == 1 ? 12 : original - 1
        XCTAssertEqual(
            controller.selectedMonth, expected)
        print("✅ test_goToPreviousMonth passed")
    }

    // MARK: - Test 7: canGoNext at current month
    func test_canGoNext_falseAtCurrentMonth() {
        // Reset to current month
        controller.selectedMonth = Calendar.current
            .component(.month, from: Date())
        controller.selectedYear  = Calendar.current
            .component(.year,  from: Date())

        XCTAssertFalse(controller.canGoNext)
        print("✅ test_canGoNext_false passed")
    }

    // MARK: - Test 8: Savings Rate
    func test_savingsRate_calculatesCorrectly() {
        controller.selectedFilter = "all"
        controller.searchText     = ""
        controller.loadMonthData()

        // netBalance = 1200, income = 2000
        // savingsRate = 60%
        XCTAssertEqual(
            controller.monthlySummary?.savingsRate,
            60.0,
            accuracy: 0.1
        )
        print("✅ test_savingsRate passed")
    }
}