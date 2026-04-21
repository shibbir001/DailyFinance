// Views/Analysis/AnalysisView.swift
import SwiftUI

struct AnalysisView: View {

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @StateObject private var controller = HistoryController.shared

    @State private var showExport    = false
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear:  Int = Calendar.current.component(.year,  from: Date())

    private let monthCount = 6

    // MARK: - Data

    var monthlyData: [(label: String, income: Double, expense: Double)] {
        var result: [(String, Double, Double)] = []
        let calendar = Calendar.current
        let now      = Date()
        let fmt      = DateFormatter(); fmt.dateFormat = "yyyy-MM"
        let labelFmt = DateFormatter(); labelFmt.dateFormat = "MMM"

        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now)
            else { continue }
            let month = calendar.component(.month, from: date)
            let year  = calendar.component(.year,  from: date)
            var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
            let key   = fmt.string(from: calendar.date(from: comps) ?? date)
            let sums  = CoreDataManager.shared.fetchAllSummaries().filter { $0.date?.hasPrefix(key) == true }
            result.append((labelFmt.string(from: date),
                           sums.reduce(0) { $0 + $1.totalIncome },
                           sums.reduce(0) { $0 + $1.totalExpense }))
        }
        return result
    }

    var totalIncome:  Double { monthlyData.reduce(0) { $0 + $1.income } }
    var totalExpense: Double { monthlyData.reduce(0) { $0 + $1.expense } }
    var totalBalance: Double { totalIncome - totalExpense }
    // Donut slices from last N months expenses
    var donutSlices: [DonutSlice] {
        let allTxs = (0..<monthCount).flatMap { i -> [TransactionEntity] in
            let cal = Calendar.current
            guard let d = cal.date(byAdding: .month, value: -i, to: Date()) else { return [] }
            return CoreDataManager.shared.fetchTransactions(
                month: cal.component(.month, from: d),
                year:  cal.component(.year,  from: d)
            )
        }
        let expenses = allTxs.filter { $0.type == "expense" }
        let byCat = Dictionary(grouping: expenses) { $0.category ?? "Other" }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(8)

        return byCat.enumerated().map { i, pair in
            DonutSlice(
                category: pair.key,
                amount:   pair.value,
                color:    Color.chartPalette[i % Color.chartPalette.count],
                icon:     categoryIcon(pair.key)
            )
        }
    }

    // Savings trend points (cumulative net)
    var trendPoints: [TrendPoint] {
        let calendar = Calendar.current
        let now      = Date()
        var cumulative = 0.0
        var points: [TrendPoint] = []
        let labelFmt = DateFormatter(); labelFmt.dateFormat = "MMM"
        let fmt      = DateFormatter(); fmt.dateFormat = "yyyy-MM"

        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now)
            else { continue }
            let month = calendar.component(.month, from: date)
            let year  = calendar.component(.year,  from: date)
            var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
            let key   = fmt.string(from: calendar.date(from: comps) ?? date)
            let sums  = CoreDataManager.shared.fetchAllSummaries().filter { $0.date?.hasPrefix(key) == true }
            let income  = sums.reduce(0) { $0 + $1.totalIncome }
            let expense = sums.reduce(0) { $0 + $1.totalExpense }
            cumulative += (income - expense)
            points.append(TrendPoint(
                label:   labelFmt.string(from: date),
                income:  income,
                expense: expense,
                net:     cumulative,
                month:   month,
                year:    year
            ))
        }
        return points
    }

    // Heatmap for selected month
    var heatmapDays: [HeatmapDay] {
        HeatmapBuilder.build(month: selectedMonth, year: selectedYear)
    }

    var heatmapMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        var c = DateComponents(); c.year = selectedYear; c.month = selectedMonth; c.day = 1
        return f.string(from: Calendar.current.date(from: c) ?? Date())
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        summaryHeader

                        // ── Chart 1: Donut (Category Breakdown) ─
                        if !donutSlices.isEmpty {
                            DonutChartView(
                                slices:      donutSlices,
                                total:       donutSlices.reduce(0) { $0 + $1.amount },
                                title:       "Spending by Category",
                                centerLabel: "Expenses"
                            )
                            .environmentObject(preferences)
                        }

                        // ── Chart 3: Savings Trend ─────────────
                        if trendPoints.count >= 2 {
                            SavingsTrendChart(points: trendPoints)
                                .environmentObject(preferences)
                                .environmentObject(theme)
                        }

                        // ── Chart 4: Spending Heatmap ──────────
                        heatmapSection

                        // ── Monthly Breakdown Table ────────────
                        monthlyBreakdown

                        // ── Export Button ──────────────────────
                        exportButton

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showExport = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                ReportExportView()
                    .environmentObject(preferences)
                    .environmentObject(theme)
            }
        }
    }

    // MARK: - Heatmap Section (with month navigator)
    var heatmapSection: some View {
        VStack(spacing: 0) {
            // Month navigator for heatmap
            HStack {
                Button {
                    navigateHeatmap(by: -1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .foregroundColor(theme.accent)
                }

                Spacer()
                Text(heatmapMonthLabel)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()

                Button {
                    navigateHeatmap(by: 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(canGoForward ? theme.accent : .gray)
                }
                .disabled(!canGoForward)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            SpendingHeatmapView(
                days:       heatmapDays,
                monthLabel: heatmapMonthLabel
            )
            .environmentObject(preferences)
            .environmentObject(theme)
        }
    }

    var canGoForward: Bool {
        let now = Date()
        let cal = Calendar.current
        return !(selectedYear == cal.component(.year, from: now) &&
                 selectedMonth == cal.component(.month, from: now))
    }

    func navigateHeatmap(by delta: Int) {
        var comps = DateComponents()
        comps.year  = selectedYear
        comps.month = selectedMonth + delta
        comps.day   = 1
        if let newDate = Calendar.current.date(from: comps) {
            let cal      = Calendar.current
            selectedMonth = cal.component(.month, from: newDate)
            selectedYear  = cal.component(.year,  from: newDate)
        }
    }

    // MARK: - Export Button
    var exportButton: some View {
        Button { showExport = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.richtext.fill").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Report").font(.subheadline).fontWeight(.bold)
                    Text("PDF or CSV balance sheet").font(.caption2).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(LinearGradient(
                colors: [theme.accent, theme.accent.opacity(0.75)],
                startPoint: .leading, endPoint: .trailing
            ))
            .cornerRadius(16)
            .shadow(color: theme.accent.opacity(0.3), radius: 8)
        }
    }

    // MARK: - Summary Header
    var summaryHeader: some View {
        VStack(spacing: 16) {
            Text("Last \(monthCount) Months")
                .font(.caption).foregroundColor(.white.opacity(0.8))
            Text(preferences.format(totalBalance))
                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 0) {
                summaryCol(label: "Income",  value: preferences.format(totalIncome))
                Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 30)
                summaryCol(label: "Expense", value: preferences.format(totalExpense))
                Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 30)
                summaryCol(
                    label: "Saved",
                    value: totalIncome > 0
                        ? String(format: "%.0f%%", (totalBalance / totalIncome) * 100)
                        : "0%"
                )
            }
        }
        .padding(20)
        .background(LinearGradient(
            colors: totalBalance >= 0
                ? [theme.accent, theme.accent.opacity(0.6)]
                : [Color.red, Color.orange],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .cornerRadius(20)
        .shadow(color: totalBalance >= 0 ? theme.accent.opacity(0.3) : .red.opacity(0.3), radius: 12)
    }

    func summaryCol(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.7))
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monthly Breakdown
    var monthlyBreakdown: some View {
        let localMax = monthlyData.map { max($0.income, $0.expense) }.max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown").font(.headline).fontWeight(.bold)
            ForEach(monthlyData.reversed(), id: \.label) { data in
                HStack {
                    Text(data.label)
                        .font(.subheadline).fontWeight(.medium)
                        .frame(width: 36, alignment: .leading)
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.8))
                                    .frame(width: localMax > 0 ? geo.size.width * CGFloat(data.income / localMax) : 0)
                                Spacer()
                            }
                        }.frame(height: 8)
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.75))
                                    .frame(width: localMax > 0 ? geo.size.width * CGFloat(data.expense / localMax) : 0)
                                Spacer()
                            }
                        }.frame(height: 8)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(preferences.format(data.income)).font(.caption).foregroundColor(.green)
                        Text(preferences.format(data.expense)).font(.caption).foregroundColor(.red)
                    }.frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 4)
                if data.label != monthlyData.last?.label { Divider() }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Helpers
    // ✅ Look up icon from Core Data — covers all 44 categories
    func categoryIcon(_ cat: String) -> String {
        let all = CoreDataManager.shared.fetchCategories(type: "expense")
            + CoreDataManager.shared.fetchCategories(type: "income")
        return all.first(where: { $0.name == cat })?.icon ?? "💳"
    }
}
