//
//  TransactionControllerTests.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//


// DailyFinanceTests/TransactionControllerTests.swift
import XCTest
@testable import DailyFinance

class TransactionControllerTests: XCTestCase {

    var controller: TransactionController!

    override func setUp() {
        super.setUp()
        controller = TransactionController.shared

        // Clear data
        let coreData = CoreDataManager.shared
        let context  = coreData.context
        let txReq: NSFetchRequest<NSFetchRequestResult>
            = TransactionEntity.fetchRequest()
        try? context.execute(
            NSBatchDeleteRequest(fetchRequest: txReq))
        let sumReq: NSFetchRequest<NSFetchRequestResult>
            = DailySummaryEntity.fetchRequest()
        try? context.execute(
            NSBatchDeleteRequest(fetchRequest: sumReq))
        context.reset()
        controller.loadTodayData()
    }

    // MARK: - Test 1: Add and Load Transaction
    func test_addTransaction_appearsInTodayList() {
        // When
        controller.addTransaction(
            type:     "expense",
            amount:   75.0,
            category: "Food",
            note:     "Test meal"
        )

        // Then
        XCTAssertEqual(
            controller.todayTransactions.count, 1)
        XCTAssertEqual(
            controller.todayTransactions.first?.amount,
            75.0)
        print("✅ test_addTransaction_appearsInList passed")
    }

    // MARK: - Test 2: Summary Updates on Add
    func test_summary_updatesOnAdd() {
        // When
        controller.addTransaction(
            type: "income", amount: 1000,
            category: "Salary", note: "Test"
        )
        controller.addTransaction(
            type: "expense", amount: 200,
            category: "Food", note: "Test"
        )

        // Then
        XCTAssertEqual(controller.todayIncome,   1000)
        XCTAssertEqual(controller.todayExpense,  200)
        XCTAssertEqual(controller.todayBalance,  800)
        XCTAssertTrue(controller.isProfit)
        print("✅ test_summary_updatesOnAdd passed")
    }

    // MARK: - Test 3: Delete Transaction
    func test_deleteTransaction_removesFromList() {
        // Given
        controller.addTransaction(
            type: "expense", amount: 50,
            category: "Food", note: "Delete"
        )
        XCTAssertEqual(
            controller.todayTransactions.count, 1)

        // When
        let transaction = controller.todayTransactions[0]
        controller.deleteTransaction(transaction)

        // Then
        XCTAssertEqual(
            controller.todayTransactions.count, 0)
        print("✅ test_deleteTransaction passed")
    }

    // MARK: - Test 4: isProfit calculation
    func test_isProfit_falseWhenExpenseHigher() {
        // When
        controller.addTransaction(
            type: "income", amount: 100,
            category: "Salary", note: "Test"
        )
        controller.addTransaction(
            type: "expense", amount: 200,
            category: "Food", note: "Test"
        )

        // Then
        XCTAssertFalse(controller.isProfit)
        XCTAssertEqual(controller.todayBalance, -100)
        print("✅ test_isProfit_false passed")
    }
}