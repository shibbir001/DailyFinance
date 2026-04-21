//
//  HeatmapDay.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Views/Charts/SpendingHeatmapView.swift
import SwiftUI

// MARK: - Heatmap Day Model
struct HeatmapDay: Identifiable {
    let id        = UUID()
    var date:     Date
    var expense:  Double
    var income:   Double
    var weekday:  Int    // 0=Sun … 6=Sat
    var weekIndex: Int   // column in the grid
}

// MARK: - Spending Heatmap View
// GitHub contribution-style grid showing daily spending intensity
struct SpendingHeatmapView: View {

    var days: [HeatmapDay]
    var monthLabel: String

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @State private var selectedDay: HeatmapDay? = nil

    private let cellSize:  CGFloat = 13
    private let cellGap:   CGFloat = 3

    let weekdayLabels = ["S","M","T","W","T","F","S"]

    var maxExpense: Double {
        days.map { $0.expense }.max() ?? 1
    }

    var totalExpense: Double { days.reduce(0) { $0 + $1.expense } }
    var totalIncome:  Double { days.reduce(0) { $0 + $1.income  } }
    var activeDays:   Int    { days.filter { $0.expense > 0 || $0.income > 0 }.count }

    // Group days by week column
    var weeks: [[HeatmapDay?]] {
        guard !days.isEmpty else { return [] }
        let maxWeek = days.map { $0.weekIndex }.max() ?? 0
        return (0...maxWeek).map { weekIdx in
            (0...6).map { wd in
                days.first { $0.weekIndex == weekIdx && $0.weekday == wd }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Spending")
                        .font(.headline).fontWeight(.bold)
                    Text(monthLabel)
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                    ForEach([0.1, 0.3, 0.55, 0.8, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(intensity: intensity))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("More")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }

            // Selected day tooltip
            if let day = selectedDay {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.accent)
                        .font(.caption)
                    Text(formatDate(day.date))
                        .font(.caption).fontWeight(.semibold)
                    Spacer()
                    if day.income > 0 {
                        Label(preferences.format(day.income), systemImage: "arrow.down")
                            .font(.caption).foregroundColor(.green)
                    }
                    if day.expense > 0 {
                        Label(preferences.format(day.expense), systemImage: "arrow.up")
                            .font(.caption).foregroundColor(.red)
                    }
                    if day.expense == 0 && day.income == 0 {
                        Text("No activity")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.lightBg)
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellGap) {

                    // Weekday labels column
                    VStack(spacing: cellGap) {
                        // Spacer for month label row
                        Color.clear.frame(width: 10, height: cellSize)
                        ForEach(weekdayLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(width: 10, height: cellSize)
                        }
                    }

                    // Week columns
                    ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                        VStack(spacing: cellGap) {
                            // Month label on first day of month
                            if let firstDay = week.compactMap({ $0 }).first,
                               Calendar.current.component(.day, from: firstDay.date) <= 7,
                               weekIdx == 0 || Calendar.current.component(.day, from: firstDay.date) == 1 {
                                Text(monthAbbr(firstDay.date))
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .frame(height: cellSize)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }

                            ForEach(0..<7, id: \.self) { wd in
                                if let day = week[wd] {
                                    let intensity = maxExpense > 0
                                        ? day.expense / maxExpense : 0
                                    let isSelected = selectedDay?.id == day.id

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(day.expense == 0 && day.income == 0
                                              ? Color(.systemGray6)
                                              : day.expense == 0
                                                ? Color.green.opacity(0.4)
                                                : cellColor(intensity: max(intensity, 0.15)))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .strokeBorder(
                                                    isSelected ? theme.accent : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .scaleEffect(isSelected ? 1.3 : 1.0)
                                        .animation(.spring(response: 0.25), value: isSelected)
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                selectedDay = selectedDay?.id == day.id ? nil : day
                                            }
                                        }
                                } else {
                                    // Empty cell (before month start or after end)
                                    Color.clear
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Summary stats
            HStack(spacing: 0) {
                statPill(
                    icon:  "calendar.badge.clock",
                    label: "Active Days",
                    value: "\(activeDays)",
                    color: theme.accent
                )
                Spacer()
                statPill(
                    icon:  "arrow.down.circle.fill",
                    label: "Income",
                    value: preferences.format(totalIncome),
                    color: .green
                )
                Spacer()
                statPill(
                    icon:  "arrow.up.circle.fill",
                    label: "Spent",
                    value: preferences.format(totalExpense),
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Cell Color
    // Low spend = yellow-orange, High spend = deep red
    func cellColor(intensity: Double) -> Color {
        let clamped = max(0, min(1, intensity))
        if clamped < 0.25 {
            return Color(red: 0.99, green: 0.88, blue: 0.60)
        } else if clamped < 0.5 {
            return Color(red: 0.99, green: 0.65, blue: 0.30)
        } else if clamped < 0.75 {
            return Color(red: 0.95, green: 0.38, blue: 0.18)
        } else {
            return Color(red: 0.78, green: 0.10, blue: 0.10)
        }
    }

    func statPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.caption).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
    }

    func formatDate(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    func monthAbbr(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

// MARK: - Heatmap Builder
// Builds HeatmapDay array from Core Data for a given month
struct HeatmapBuilder {
    static func build(month: Int, year: Int) -> [HeatmapDay] {
        let calendar   = Calendar.current
        var components = DateComponents()
        components.year  = year
        components.month = month
        components.day   = 1

        guard let firstDay = calendar.date(from: components),
              let range    = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let coreData     = CoreDataManager.shared
        let txs          = coreData.fetchTransactions(month: month, year: year)

        let fmt        = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        var days: [HeatmapDay] = []

        for day in range {
            components.day = day
            guard let date = calendar.date(from: components) else { continue }

            let dateStr = fmt.string(from: date)
            let dayTxs  = txs.filter { tx in
                guard let d = tx.date else { return false }
                return fmt.string(from: d) == dateStr
            }

            let expense  = dayTxs.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
            let income   = dayTxs.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount }
            let weekday  = (firstWeekday + day - 1) % 7
            let weekIdx  = (firstWeekday + day - 1) / 7

            days.append(HeatmapDay(
                date:      date,
                expense:   expense,
                income:    income,
                weekday:   weekday,
                weekIndex: weekIdx
            ))
        }
        return days
    }
}