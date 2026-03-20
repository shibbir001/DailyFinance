//
//  Transaction.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//

// Models/Transaction.swift
import Foundation

struct Transaction: Codable, Identifiable {
    var id: UUID
    var type: String        // "income" or "expense"
    var amount: Double
    var category: String
    var note: String
    var date: Date

    init(type: String, amount: Double,
         category: String, note: String) {
        self.id       = UUID()
        self.type     = type
        self.amount   = amount
        self.category = category
        self.note     = note
        self.date     = Date()
    }
}
