// Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {

    // MARK: - Properties
    @StateObject private var controller = HistoryController.shared
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var showingSearch   = false
    @State private var showCalendar    = false   // ✅ new

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Month Navigator
                    monthNavigator

                    // MARK: Monthly Stats Card
                    if let summary = controller.monthlySummary {
                        monthlyStatsCard(summary: summary)
                            .onTapGesture {
                                showCalendar = true   // ✅ tap to open calendar
                            }

                        // Hint label
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption)
                            Text("Tap card to open calendar view")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, -10)

                        categoryBreakdown(summary: summary)
                    }

                    // MARK: Filter Bar
                    filterBar

                    // MARK: Search Bar
                    if showingSearch {
                        searchBar
                    }

                    // MARK: Transactions List
                    TransactionListView(
                        transactions: controller.monthTransactions,
                        title: "Transactions"
                    )

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.loadMonthData() }
        // ✅ Reload on Supabase restore
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("DataRestored")
            )
        ) { _ in controller.loadMonthData() }
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // ✅ Calendar button
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                    }

                    // Search button
                    Button {
                        withAnimation {
                            showingSearch.toggle()
                        }
                    } label: {
                        Image(systemName: showingSearch
                              ? "xmark.circle"
                              : "magnifyingglass")
                    }
                }
            }
        }
        .onChange(of: controller.searchText) { _ in
            controller.loadMonthData()
        }
        // ✅ Open calendar sheet
        .sheet(isPresented: $showCalendar) {
            MonthCalendarView(
                month: controller.selectedMonth,
                year:  controller.selectedYear
            )
            .environmentObject(preferences)
            .onDisappear {
                controller.loadMonthData()
            }
        }
    }

    // MARK: - Month Navigator
    var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.spring()) {
                    controller.goToPreviousMonth()
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }

            Spacer()

            // ✅ Tap month name to open calendar
            Button {
                showCalendar = true
            } label: {
                VStack(spacing: 2) {
                    Text(controller.monthName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("\(controller.monthlySummary?.transactionCount ?? 0) transactions • tap for calendar")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring()) {
                    controller.goToNextMonth()
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(controller.canGoNext ? theme.accent : .gray)
            }
            .disabled(!controller.canGoNext)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Monthly Stats Card
    func monthlyStatsCard(summary: MonthlySummary) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Net Balance")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                Text(formatCurrency(summary.netBalance))
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: summary.isProfit
                          ? "arrow.up.circle.fill"
                          : "arrow.down.circle.fill")
                    Text(String(format: "%.1f%% savings rate",
                                summary.savingsRate))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2))
                .cornerRadius(20)
            }

            Divider().background(.white.opacity(0.3))

            HStack {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green.opacity(0.9))
                        Text("Income").font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.85))
                    Text(formatCurrency(summary.totalIncome))
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red.opacity(0.9))
                        Text("Expense").font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.85))
                    Text(formatCurrency(summary.totalExpense))
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }

            // ✅ Tap hint
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Tap to view calendar")
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: summary.isProfit
                    ? [theme.accent, theme.accent.opacity(0.6)]
                    : [Color.red, Color.orange],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(
            color: summary.isProfit ? theme.accent.opacity(0.3) : Color.red.opacity(0.3),
            radius: 12
        )
    }

    // MARK: - Category Breakdown
    func categoryBreakdown(summary: MonthlySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending Breakdown")
                .font(.headline).fontWeight(.bold)

            if summary.expenseByCategory.isEmpty {
                Text("No expenses this month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                let sorted = summary.expenseByCategory
                    .sorted { $0.value > $1.value }

                ForEach(sorted, id: \.key) { category, amount in
                    CategoryBarRow(
                        category: category,
                        amount:   amount,
                        total:    summary.totalExpense
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Filter Bar
    var filterBar: some View {
        HStack(spacing: 10) {
            ForEach(["all", "income", "expense"], id: \.self) { filter in
                Button {
                    withAnimation(.spring()) {
                        controller.selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterIcon(filter)).font(.caption)
                        Text(filter.capitalized).font(.subheadline).fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        controller.selectedFilter == filter
                        ? filterColor(filter)
                        : Color(.systemBackground)
                    )
                    .foregroundColor(
                        controller.selectedFilter == filter ? .white : .primary
                    )
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                }
            }
            Spacer()
        }
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search by note or category...", text: $controller.searchText)
            if !controller.searchText.isEmpty {
                Button {
                    controller.searchText = ""
                    controller.loadMonthData()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helpers
    func filterIcon(_ filter: String) -> String {
        switch filter {
        case "income":  return "arrow.down.circle.fill"
        case "expense": return "arrow.up.circle.fill"
        default:        return "list.bullet"
        }
    }

    func filterColor(_ filter: String) -> Color {
        switch filter {
        case "income":  return .green
        case "expense": return .red
        default:        return .blue
        }
    }

    func formatCurrency(_ value: Double) -> String {
        return preferences.format(value)
    }
}

// MARK: - Category Bar Row
struct CategoryBarRow: View {
    var category: String
    var amount:   Double
    var total:    Double

    var percentage: Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }

    var icon: String {
        let icons: [String: String] = [
            "Food": "🍔", "Rent": "🏠", "Transport": "🚗",
            "Health": "💊", "Shopping": "🛍️",
            "Education": "📚", "Other": "📌"
        ]
        return icons[category] ?? "💳"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(icon)
                Text(category).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption).foregroundColor(.secondary)
                Text(formatCurrency(amount))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: geo.size.width * (percentage / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    func formatCurrency(_ value: Double) -> String {
        return UserPreferences.shared.format(value)
    }
}
