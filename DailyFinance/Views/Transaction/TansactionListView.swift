//
//  TansactionListView.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//
// Views/Transaction/TransactionListView.swift
import SwiftUI

struct TransactionListView: View {

    var transactions: [TransactionEntity]
    var title:        String = "Transactions"

    @StateObject private var controller
        = TransactionController.shared

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
                // Empty state
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
                // Group by date
                let grouped = groupByDate(transactions)

                ForEach(grouped.keys.sorted().reversed(),
                    id: \.self
                ) { dateKey in
                    if let dayTransactions = grouped[dateKey] {

                        // Date header
                        Text(dateKey)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        // Transactions for that day
                        VStack(spacing: 0) {
                            ForEach(
                                dayTransactions,
                                id: \.id
                            ) { transaction in
                                TransactionRowView(
                                    transaction: transaction
                                )
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        controller
                                            .deleteTransaction(
                                                transaction
                                            )
                                    } label: {
                                        Label("Delete",
                                            systemImage: "trash")
                                    }
                                }

                                if transaction != dayTransactions.last {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(
                            color: .black.opacity(0.05),
                            radius: 6
                        )
                    }
                }
            }
        }
    }

    // Group transactions by date string
    func groupByDate(
        _ transactions: [TransactionEntity]
    ) -> [String: [TransactionEntity]] {

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return Dictionary(
            grouping: transactions
        ) { transaction in
            guard let date = transaction.date else {
                return "Unknown"
            }
            return formatter.string(from: date)
        }
    }
}
