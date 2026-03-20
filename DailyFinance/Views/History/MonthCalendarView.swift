// Views/History/MonthCalendarView.swift
import SwiftUI

struct MonthCalendarView: View {

    // MARK: - Properties
    var month: Int
    var year:  Int

    @StateObject private var controller = HistoryController.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate:     Date? = nil
    @State private var showDayView:      Bool  = false
    @State private var dailyData:        [String: (income: Double, expense: Double)] = [:]

    @EnvironmentObject private var preferences: UserPreferences
    let coreData   = CoreDataManager.shared
    let columns    = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdays   = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: - Computed
    var monthName: String {
        let f        = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        var c        = DateComponents()
        c.year       = year
        c.month      = month
        c.day        = 1
        let date = Calendar.current.date(from: c) ?? Date()
        return f.string(from: date)
    }

    var daysInMonth: [Date?] {
        var components   = DateComponents()
        components.year  = year
        components.month = month
        components.day   = 1

        let calendar  = Calendar.current
        guard let firstDay = calendar.date(from: components)
        else { return [] }

        let weekday    = calendar.component(.weekday, from: firstDay)
        let totalDays  = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)

        for day in 1...totalDays {
            components.day = day
            days.append(calendar.date(from: components))
        }

        return days
    }

    var today: Date { Calendar.current.startOfDay(for: Date()) }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: Month Stats
                        monthStatsBar

                        // MARK: Calendar Grid
                        calendarGrid

                        // MARK: Legend
                        legend

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(monthName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadDailyData() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("DataRestored")
                )
            ) { _ in loadDailyData() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("iCloudDataChanged")
                )
            ) { _ in loadDailyData() }
            // ✅ React when controller data updates
            .onChange(of: controller.calendarDailyData.count) { _ in
                loadDailyData()
            }
            .sheet(isPresented: $showDayView) {
                if let date = selectedDate {
                    CalendarDayView(date: date)
                        .environmentObject(preferences)
                        .onDisappear { loadDailyData() }
                }
            }
        }
    }

    // MARK: - Month Stats Bar
    var monthStatsBar: some View {
        let summary = controller.monthlySummary

        return HStack(spacing: 0) {
            // Income
            VStack(spacing: 4) {
                Text("Income")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatCurrency(summary?.totalIncome ?? 0))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // Expense
            VStack(spacing: 4) {
                Text("Expense")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatCurrency(summary?.totalExpense ?? 0))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // Balance
            VStack(spacing: 4) {
                Text("Balance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatCurrency(summary?.netBalance ?? 0))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(
                        (summary?.isProfit ?? true) ? .green : .red
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Calendar Grid
    var calendarGrid: some View {
        VStack(spacing: 12) {

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Days grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<daysInMonth.count, id: \.self) { i in
                    if let date = daysInMonth[i] {
                        dayCell(date: date)
                    } else {
                        Color.clear
                            .frame(height: 56)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Day Cell
    func dayCell(date: Date) -> some View {
        let calendar   = Calendar.current
        let day        = calendar.component(.day, from: date)
        let isToday    = calendar.isDate(date, inSameDayAs: today)
        let isFuture   = calendar.startOfDay(for: date) > today
        let dateKey    = dateString(date)
        let data       = dailyData[dateKey]
        let income     = data?.income  ?? 0
        let expense    = data?.expense ?? 0
        let hasIncome  = income  > 0
        let hasExpense = expense > 0
        let hasData    = hasIncome || hasExpense

        // Circle color logic
        let circleColor: Color = {
            if isToday                 { return .blue }
            if hasIncome && hasExpense { return .blue }
            if hasIncome               { return .green }
            if hasExpense              { return .red }
            return .clear
        }()
        let hasFill = hasData || isToday

        return Button {
            if !isFuture {
                selectedDate = date
                showDayView  = true
            }
        } label: {
            VStack(spacing: 2) {

                // Day number with colored circle
                ZStack {
                    Circle()
                        .fill(hasFill
                              ? circleColor.opacity(isToday ? 1.0 : 0.15)
                              : Color.clear)
                        .frame(width: 28, height: 28)

                    if hasData && !isToday {
                        Circle()
                            .strokeBorder(circleColor, lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                    }

                    Text("\(day)")
                        .font(.system(
                            size: 12,
                            weight: (isToday || hasData) ? .semibold : .regular
                        ))
                        .foregroundColor(
                            isFuture  ? .secondary.opacity(0.35) :
                            isToday   ? .white :
                            hasData   ? circleColor : .primary
                        )
                }

                // Income amount
                if hasIncome {
                    Text(formatAmount(income))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(" ").font(.system(size: 8))
                }

                // Expense amount
                if hasExpense {
                    Text(formatAmount(expense))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(" ").font(.system(size: 8))
                }
            }
            .frame(height: 62)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .cornerRadius(10)
        }
        .disabled(isFuture)
    }

    // MARK: - Legend
    var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: "Income")
            legendItem(color: .red,   label: "Expense")
            legendItem(color: .blue,  label: "Both")
            Spacer()
            Text("Tap to view")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Load Daily Data
    // ✅ Uses HistoryController.calendarDailyData
    // which is always up to date — loaded by controller
    // even when this view is not open
    func loadDailyData() {
        // ✅ Primary: use pre-loaded controller data
        let controllerData = controller.calendarDailyData
        if !controllerData.isEmpty {
            dailyData = controllerData
            print("📅 Calendar loaded \(controllerData.count) days from controller")
            return
        }

        // ✅ Fallback: load directly from Core Data
        var data: [String: (income: Double, expense: Double)] = [:]

        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var components       = DateComponents()
        components.year      = year
        components.month     = month
        components.day       = 1
        let monthDate = Calendar.current
            .date(from: components) ?? Date()
        let monthKey  = formatter.string(from: monthDate)

        let allSummaries = coreData.fetchAllSummaries()
        let monthSummaries = allSummaries.filter {
            $0.date?.hasPrefix(monthKey) == true
        }

        for summary in monthSummaries {
            guard let dateStr = summary.date else { continue }
            data[dateStr] = (
                income:  summary.totalIncome,
                expense: summary.totalExpense
            )
        }

        if !data.isEmpty {
            dailyData = data
            print("📅 Calendar loaded \(data.count) days from CoreData")
        } else {
            // Last fallback: transactions
            let transactions = coreData.fetchTransactions(
                month: month, year: year
            )
            for tx in transactions {
                guard let date = tx.date else { continue }
                let key   = dateString(date)
                var entry = data[key] ?? (income: 0, expense: 0)
                if tx.type == "income" {
                    entry.income  += tx.amount
                } else {
                    entry.expense += tx.amount
                }
                data[key] = entry
            }
            dailyData = data
            print("📅 Calendar loaded \(transactions.count) from transactions")
        }
    }

    // MARK: - Helpers
    func dateString(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func formatCurrency(_ value: Double) -> String {
        return preferences.format(value)
    }

    // ✅ Compact amount for calendar cells
    func formatAmount(_ amount: Double) -> String {
        let symbol: String
        switch preferences.currency {
        case "GBP": symbol = "£"
        case "EUR": symbol = "€"
        case "CAD": symbol = "C$"
        case "AUD": symbol = "A$"
        default:    symbol = "$"
        }
        // No decimals for whole numbers
        // Compact for 1000+
        if amount >= 1000 {
            return "\(symbol)\(String(format: "%.1f", amount/1000))k"
        } else if amount == Double(Int(amount)) {
            return "\(symbol)\(Int(amount))"
        } else {
            return String(format: "\(symbol)%.1f", amount)
        }
    }
}
