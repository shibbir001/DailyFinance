// Views/Analysis/AnalysisView.swift
import SwiftUI

struct AnalysisView: View {

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @StateObject private var controller = HistoryController.shared

    // Show last 6 months
    private let monthCount = 6

    var monthlyData: [(label: String, income: Double, expense: Double)] {
        var result: [(String, Double, Double)] = []
        let calendar  = Calendar.current
        let now       = Date()

        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(
                byAdding: .month, value: -i, to: now
            ) else { continue }

            let month = calendar.component(.month, from: date)
            let year  = calendar.component(.year,  from: date)

            // Get summaries for this month
            let formatter        = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            var comps            = DateComponents()
            comps.year           = year
            comps.month          = month
            comps.day            = 1
            let monthDate = calendar.date(from: comps) ?? date
            let monthKey  = formatter.string(from: monthDate)

            let summaries = CoreDataManager.shared
                .fetchAllSummaries()
                .filter { $0.date?.hasPrefix(monthKey) == true }

            let income  = summaries.reduce(0) { $0 + $1.totalIncome }
            let expense = summaries.reduce(0) { $0 + $1.totalExpense }

            let labelF        = DateFormatter()
            labelF.dateFormat = "MMM"
            let label = labelF.string(from: date)

            result.append((label, income, expense))
        }
        return result
    }

    var totalIncome:  Double { monthlyData.reduce(0) { $0 + $1.income } }
    var totalExpense: Double { monthlyData.reduce(0) { $0 + $1.expense } }
    var totalBalance: Double { totalIncome - totalExpense }
    var maxValue:     Double { monthlyData.map { max($0.income, $0.expense) }.max() ?? 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: 6 Month Summary
                        summaryHeader

                        // MARK: Bar Chart
                        barChart

                        // MARK: Monthly Breakdown
                        monthlyBreakdown

                        // MARK: Spending by Category
                        categoryAnalysis

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Summary Header
    var summaryHeader: some View {
        VStack(spacing: 16) {
            Text("Last 6 Months")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(preferences.format(totalBalance))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Income")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(preferences.format(totalIncome))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 30)

                VStack(spacing: 4) {
                    Text("Expense")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(preferences.format(totalExpense))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 30)

                VStack(spacing: 4) {
                    Text("Saved")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(totalIncome > 0
                         ? String(format: "%.0f%%",
                            (totalBalance / totalIncome) * 100)
                         : "0%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: totalBalance >= 0
                    ? [theme.accent, theme.accent.opacity(0.6)]
                    : [Color.red, Color.orange],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(
            color: totalBalance >= 0
                ? theme.accent.opacity(0.3)
                : .red.opacity(0.3),
            radius: 12
        )
    }

    // MARK: - Bar Chart
    var barChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Overview")
                .font(.headline)
                .fontWeight(.bold)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Expense")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(monthlyData, id: \.label) { data in
                    VStack(spacing: 4) {
                        // Income bar
                        GeometryReader { geo in
                            VStack(spacing: 2) {
                                Spacer()
                                // Income
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(
                                        height: maxValue > 0
                                        ? geo.size.height
                                            * CGFloat(data.income / maxValue)
                                        : 0
                                    )
                                    .animation(.spring(), value: data.income)
                            }
                        }
                        .frame(height: 120)

                        // Expense bar
                        GeometryReader { geo in
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red.opacity(0.7))
                                    .frame(
                                        height: maxValue > 0
                                        ? geo.size.height
                                            * CGFloat(data.expense / maxValue)
                                        : 0
                                    )
                                    .animation(.spring(), value: data.expense)
                                Spacer()
                            }
                        }
                        .frame(height: 80)

                        Text(data.label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Monthly Breakdown
    var monthlyBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(monthlyData.reversed(), id: \.label) { data in
                HStack {
                    Text(data.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 36, alignment: .leading)

                    VStack(spacing: 2) {
                        // Income bar
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(
                                        width: maxValue > 0
                                        ? geo.size.width
                                            * CGFloat(data.income / maxValue)
                                        : 0
                                    )
                                Spacer()
                            }
                        }
                        .frame(height: 8)

                        // Expense bar
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.red.opacity(0.7))
                                    .frame(
                                        width: maxValue > 0
                                        ? geo.size.width
                                            * CGFloat(data.expense / maxValue)
                                        : 0
                                    )
                                Spacer()
                            }
                        }
                        .frame(height: 8)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(preferences.format(data.income))
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(preferences.format(data.expense))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if data.label != monthlyData.last?.label {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Category Analysis
    var categoryAnalysis: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Spending Categories")
                .font(.headline)
                .fontWeight(.bold)

            let allTransactions = (0..<monthCount).flatMap { i -> [TransactionEntity] in
                let calendar = Calendar.current
                guard let date = calendar.date(
                    byAdding: .month, value: -i, to: Date()
                ) else { return [] }
                let month = calendar.component(.month, from: date)
                let year  = calendar.component(.year,  from: date)
                return CoreDataManager.shared.fetchTransactions(
                    month: month, year: year
                )
            }

            let expenses = allTransactions.filter { $0.type == "expense" }
            let totalExp = expenses.reduce(0) { $0 + $1.amount }

            let byCategory = Dictionary(grouping: expenses) {
                $0.category ?? "Other"
            }.mapValues {
                $0.reduce(0) { $0 + $1.amount }
            }.sorted { $0.value > $1.value }.prefix(5)

            if byCategory.isEmpty {
                Text("No expense data yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(byCategory), id: \.key) { cat, amount in
                    let pct = totalExp > 0 ? amount / totalExp : 0
                    VStack(spacing: 6) {
                        HStack {
                            Text(categoryIcon(cat))
                            Text(cat)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1f%%", pct * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(preferences.format(amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * CGFloat(pct),
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    func categoryIcon(_ cat: String) -> String {
        let icons: [String: String] = [
            "Food": "🍔", "Rent": "🏠", "Transport": "🚗",
            "Health": "💊", "Shopping": "🛍️",
            "Education": "📚", "Other": "📌",
            "Salary": "💰", "Freelance": "💼"
        ]
        return icons[cat] ?? "💳"
    }
}
