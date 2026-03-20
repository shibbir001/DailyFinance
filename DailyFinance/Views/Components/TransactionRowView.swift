// Views/Components/TransactionRowView.swift
import SwiftUI

struct TransactionRowView: View {

    var transaction: TransactionEntity
    // ✅ Live currency updates
    @EnvironmentObject private var preferences: UserPreferences

    var body: some View {
        HStack(spacing: 14) {

            // Category Icon Circle
            ZStack {
                Circle()
                    .fill(transaction.type == "income"
                        ? Color.green.opacity(0.15)
                        : Color.red.opacity(0.15))
                    .frame(width: 46, height: 46)
                Text(categoryIcon(transaction.category ?? ""))
                    .font(.title3)
            }

            // Note + Category
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note ?? "No note")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.category ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount + Time
            VStack(alignment: .trailing, spacing: 4) {
                // ✅ Uses preferences.symbol for currency
                Text("\(transaction.type == "income" ? "+" : "-")\(preferences.format(transaction.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        transaction.type == "income"
                        ? .green : .red
                    )

                Text(formatTime(transaction.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    func categoryIcon(_ category: String) -> String {
        let icons: [String: String] = [
            "Salary":    "💰",
            "Freelance": "💼",
            "Business":  "📈",
            "Food":      "🍔",
            "Rent":      "🏠",
            "Transport": "🚗",
            "Health":    "💊",
            "Shopping":  "🛍️",
            "Education": "📚",
            "Other":     "📌"
        ]
        return icons[category] ?? "💳"
    }

    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f        = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: date)
    }
}
