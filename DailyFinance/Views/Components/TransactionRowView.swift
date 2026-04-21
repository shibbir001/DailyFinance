// Views/Components/TransactionRowView.swift
import SwiftUI

struct TransactionRowView: View {

    // ✅ @ObservedObject makes SwiftUI subscribe to this
    // NSManagedObject directly. When amount, type, note,
    // or category changes in Core Data, this row re-renders
    // automatically — no notification or refreshID needed.
    @ObservedObject var transaction: TransactionEntity

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
        // ✅ Look up from Core Data — covers all 44 categories
        let all = CoreDataManager.shared.fetchCategories(type: "expense")
                + CoreDataManager.shared.fetchCategories(type: "income")
        return all.first(where: { $0.name == category })?.icon ?? "💳"
    }

    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f        = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: date)
    }
}
