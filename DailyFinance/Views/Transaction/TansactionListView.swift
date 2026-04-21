// Views/Transaction/TransactionListView.swift
import SwiftUI

struct TransactionListView: View {

    var transactions: [TransactionEntity]
    var title:        String = "Transactions"

    @StateObject private var controller = TransactionController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(transactions.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if transactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No transactions found")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

            } else {
                let grouped = groupByDate(transactions)

                ForEach(grouped.keys.sorted().reversed(), id: \.self) { dateKey in
                    if let dayTransactions = grouped[dateKey] {

                        Text(dateKey)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            // ✅ Key includes amount + type so any edit
                            // produces a new identity → SwiftUI rebuilds the row
                            ForEach(dayTransactions, id: \.stableRenderKey) { transaction in
                                TransactionRowView(transaction: transaction)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            controller.deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }

                                if transaction != dayTransactions.last {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6)
                    }
                }
            }
        }
    }

    func groupByDate(_ transactions: [TransactionEntity]) -> [String: [TransactionEntity]] {
        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Dictionary(grouping: transactions) { tx in
            guard let date = tx.date else { return "Unknown" }
            return formatter.string(from: date)
        }
    }
}

// MARK: - Stable render key
// ✅ Combines UUID + amount + type into one string.
// ForEach uses this as identity — when amount or type
// changes after an edit, the key changes and SwiftUI
// throws away the old row and builds a fresh one.
private extension TransactionEntity {
    var stableRenderKey: String {
        "\(id?.uuidString ?? "x")-\(amount)-\(type ?? "")"
    }
}
