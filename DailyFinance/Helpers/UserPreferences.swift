// Helpers/UserPreferences.swift
import Foundation
import SwiftUI
import Combine

// ✅ Shared observable — all views react to changes
class UserPreferences: ObservableObject {

    // MARK: - Singleton
    static let shared = UserPreferences()

    // MARK: - Published (views auto-update)
    @Published var currency: String {
        didSet {
            UserDefaults.standard.set(
                currency,
                forKey: "userCurrency"
            )
            print("✅ Currency changed to: \(currency)")
        }
    }

    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(
                userName,
                forKey: "userName_\(AuthController.shared.currentUserId)"
            )
        }
    }

    // ✅ iCloud sync preference
    @Published var iCloudEnabled: Bool {
        didSet {
            CoreDataManager.shared.isICloudEnabled = iCloudEnabled
            print(iCloudEnabled
                  ? "☁️ iCloud sync enabled"
                  : "💾 iCloud sync disabled")
        }
    }

    // MARK: - Currency Info
    let currencies = ["USD", "GBP", "EUR", "CAD", "AUD"]

    let currencySymbols: [String: String] = [
        "USD": "$",
        "GBP": "£",
        "EUR": "€",
        "CAD": "CA$",
        "AUD": "A$"
    ]

    var symbol: String {
        currencySymbols[currency] ?? "$"
    }

    // ✅ Format any amount with current currency
    func format(_ amount: Double) -> String {
        let formatter            = NumberFormatter()
        formatter.numberStyle    = .currency
        formatter.currencySymbol = symbol
        return formatter.string(
            from: NSNumber(value: amount)
        ) ?? "\(symbol)0.00"
    }

    // MARK: - Init
    private init() {
        self.currency      = UserDefaults.standard
            .string(forKey: "userCurrency") ?? "USD"
        self.userName      = UserDefaults.standard
            .string(forKey: "userName_") ?? ""
        self.iCloudEnabled = UserDefaults.standard
            .bool(forKey: "iCloudSyncEnabled")
    }

    // MARK: - Load for user
    func loadForUser(_ userId: String) {
        userName = UserDefaults.standard
            .string(forKey: "userName_\(userId)") ?? ""
    }
}
