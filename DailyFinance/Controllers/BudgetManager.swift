// Controllers/BudgetManager.swift
// ✅ Uses UserDefaults — no Core Data entity needed
// No xcdatamodeld changes required
import Foundation
import Combine
import UserNotifications

// MARK: - Budget Model (Codable — stored in UserDefaults)
struct Budget: Codable, Identifiable {
    var id:           UUID   = UUID()
    var category:     String          // "" = total monthly budget
    var monthlyLimit: Double
    var isActive:     Bool   = true
    var createdAt:    Date   = Date()

    var isTotalBudget: Bool { category.isEmpty }
    var label: String { category.isEmpty ? "Total Budget" : category }
}

// MARK: - Budget Status
struct BudgetStatus: Identifiable {
    var id:       UUID   { budget.id }
    var budget:   Budget
    var spent:    Double
    var icon:     String

    var limit:      Double { budget.monthlyLimit }
    var remaining:  Double { max(0, limit - spent) }
    var fraction:   Double { limit > 0 ? min(spent / limit, 1.0) : 0 }
    var isExceeded: Bool   { spent > limit }
    var isWarning:  Bool   { fraction >= 0.8 && !isExceeded }
    var isSafe:     Bool   { fraction < 0.8 }
    var label:      String { budget.label }
    var category:   String { budget.category }
}

// MARK: - BudgetManager
final class BudgetManager: ObservableObject {

    static let shared = BudgetManager()

    @Published var budgets:        [Budget]       = []
    @Published var budgetStatuses: [BudgetStatus] = []

    private let coreData  = CoreDataManager.shared
    private let storageKey = "dailyfinance_budgets"

    private init() {
        requestNotificationPermission()
        loadBudgets()
    }

    // MARK: - Load
    func loadBudgets() {
        let userId = coreData.currentUserId
        let key    = "\(storageKey)_\(userId.isEmpty ? "default" : userId)"
        if let data    = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Budget].self, from: data) {
            budgets = decoded.filter { $0.isActive }
        } else {
            budgets = []
        }
        recalculateStatuses()
    }

    // MARK: - Save
    private func saveBudgets() {
        let userId = coreData.currentUserId
        let key    = "\(storageKey)_\(userId.isEmpty ? "default" : userId)"
        if let data = try? JSONEncoder().encode(budgets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Recalculate Statuses
    func recalculateStatuses() {
        let now   = Date()
        let cal   = Calendar.current
        let month = cal.component(.month, from: now)
        let year  = cal.component(.year,  from: now)

        let monthTxs = coreData.fetchTransactions(month: month, year: year)
            .filter { $0.type == "expense" }

        budgetStatuses = budgets.map { budget in
            let spent: Double
            if budget.category.isEmpty {
                spent = monthTxs.reduce(0) { $0 + $1.amount }
            } else {
                spent = monthTxs
                    .filter { ($0.category ?? "") == budget.category }
                    .reduce(0) { $0 + $1.amount }
            }
            let status = BudgetStatus(
                budget: budget,
                spent:  spent,
                icon:   categoryIcon(budget.category)
            )
            if status.isExceeded       { scheduleExceededNotification(status: status) }
            else if status.isWarning   { scheduleWarningNotification(status: status) }
            return status
        }
    }

    // MARK: - Add
    @discardableResult
    func addBudget(category: String, monthlyLimit: Double) -> Budget {
        // Remove existing for same category
        budgets.removeAll { $0.category == category }
        let budget = Budget(category: category, monthlyLimit: monthlyLimit)
        budgets.append(budget)
        saveBudgets()
        recalculateStatuses()
        return budget
    }

    // MARK: - Update
    func updateBudget(id: UUID, monthlyLimit: Double) {
        if let idx = budgets.firstIndex(where: { $0.id == id }) {
            budgets[idx].monthlyLimit = monthlyLimit
            saveBudgets()
            recalculateStatuses()
        }
    }

    // MARK: - Delete
    func deleteBudget(id: UUID) {
        budgets.removeAll { $0.id == id }
        saveBudgets()
        recalculateStatuses()
    }

    // MARK: - Check After Transaction
    func checkAfterTransaction(category: String, type: String) {
        guard type == "expense" else { return }
        recalculateStatuses()
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            print(granted ? "✅ Notifications allowed" : "❌ Notifications denied")
        }
    }

    private func scheduleExceededNotification(status: BudgetStatus) {
        let key = "budget_exceeded_\(status.label)_\(currentMonthKey)"
        guard !notificationFired(key: key) else { return }
        markNotificationFired(key: key)
        let content   = UNMutableNotificationContent()
        content.title = "Budget Exceeded \(status.icon)"
        content.body  = "\(status.label) exceeded by \(UserPreferences.shared.format(status.spent - status.limit))"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
        )
    }

    private func scheduleWarningNotification(status: BudgetStatus) {
        let key = "budget_warning_\(status.label)_\(currentMonthKey)"
        guard !notificationFired(key: key) else { return }
        markNotificationFired(key: key)
        let content   = UNMutableNotificationContent()
        content.title = "Budget Warning ⚠️"
        content.body  = "\(status.label): \(Int(status.fraction * 100))% of \(UserPreferences.shared.format(status.limit)) used"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: key, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
        )
    }

    private var currentMonthKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private func notificationFired(key: String) -> Bool {
        UserDefaults.standard.bool(forKey: "notif_\(key)")
    }

    private func markNotificationFired(key: String) {
        UserDefaults.standard.set(true, forKey: "notif_\(key)")
    }

    // MARK: - Helpers
    func categoryIcon(_ cat: String) -> String {
        let icons: [String: String] = [
            "":              "💰", "Groceries":     "🛒",
            "Restaurant":    "🍽️", "Coffee":        "☕️",
            "Rent":          "🏠", "Utilities":     "⚡️",
            "Internet":      "📡", "Fuel":          "⛽️",
            "Taxi/Uber":     "🚕", "Medicine":      "💊",
            "Doctor":        "🩺", "Gym":           "🏋️",
            "Clothes":       "👗", "Electronics":   "📱",
            "Movies":        "🎬", "Education":     "🎓",
            "Pet":           "🐾", "Travel":        "🌍",
            "Subscriptions": "📺", "Other":         "📌",
        ]
        return icons[cat] ?? "💳"
    }

    var exceededCount: Int { budgetStatuses.filter { $0.isExceeded }.count }
    var warningCount:  Int { budgetStatuses.filter { $0.isWarning  }.count }
}
