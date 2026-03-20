//
//  DailySummary.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//

import Foundation

struct DailySummary: Codable {
    var userId: String
    var date: String              // "2026-03-07"
    var totalIncome: Double
    var totalExpense: Double
    var netBalance: Double
    var transactions: [Transaction]

    // Computed
    var isProfit: Bool {
        return netBalance >= 0
    }
}
