// Views/Dashboard/MonthlyExpenseChartCard.swift
import SwiftUI

struct MonthlyExpenseChartCard: View {

    @EnvironmentObject private var preferences: UserPreferences

    // Daily expense data for current month
    var dailyData: [DailyExpensePoint]

    // MARK: - Computed
    var totalExpense: Double {
        dailyData.reduce(0) { $0 + $1.expense }
    }

    var maxPoint: DailyExpensePoint? {
        dailyData.filter { $0.expense > 0 }
            .max(by: { $0.expense < $1.expense })
    }

    var minPoint: DailyExpensePoint? {
        dailyData.filter { $0.expense > 0 }
            .min(by: { $0.expense < $1.expense })
    }

    var maxExpense: Double {
        dailyData.map { $0.expense }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthLabel())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(preferences.format(totalExpense))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Legend
                VStack(alignment: .trailing, spacing: 6) {
                    if let peak = maxPoint {
                        legendItem(
                            color: .red,
                            label: "Peak \(preferences.format(peak.expense))"
                        )
                    }
                    if let low = minPoint {
                        legendItem(
                            color: .green,
                            label: "Low \(preferences.format(low.expense))"
                        )
                    }
                }
                .font(.caption2)
            }

            // MARK: Chart
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ✅ Fill area under curve
                    curveShape(width: geo.size.width,
                               height: geo.size.height)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.15),
                                    Color.blue.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint:   .bottom
                            )
                        )

                    // ✅ Curve line
                    curvePath(width: geo.size.width,
                              height: geo.size.height)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap:   .round,
                                lineJoin:  .round
                            )
                        )

                    // ✅ Bars + dots
                    ForEach(
                        Array(dailyData.enumerated()),
                        id: \.element.day
                    ) { index, point in
                        let x = xPosition(
                            index: index,
                            width: geo.size.width
                        )
                        let h = barHeight(
                            expense: point.expense,
                            totalHeight: geo.size.height
                        )

                        if point.expense > 0 {
                            // Peak bar — red
                            if point.day == maxPoint?.day {
                                Rectangle()
                                    .fill(Color.red.opacity(0.2))
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(
                                                Color.red,
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 8, height: h)
                                    .cornerRadius(3)
                                    .position(
                                        x: x,
                                        y: geo.size.height - h / 2
                                    )

                                // Peak label
                                Text(preferences.format(point.expense))
                                    .font(.system(size: 9,
                                                  weight: .semibold))
                                    .foregroundColor(.red)
                                    .position(
                                        x: x,
                                        y: geo.size.height - h - 8
                                    )

                            // Min bar — green
                            } else if point.day == minPoint?.day {
                                Rectangle()
                                    .fill(Color.green.opacity(0.2))
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(
                                                Color.green,
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 8, height: h)
                                    .cornerRadius(3)
                                    .position(
                                        x: x,
                                        y: geo.size.height - h / 2
                                    )

                                // Min label
                                Text(preferences.format(point.expense))
                                    .font(.system(size: 9,
                                                  weight: .semibold))
                                    .foregroundColor(.green)
                                    .position(
                                        x: x,
                                        y: geo.size.height - h - 8
                                    )

                            } else {
                                // Normal dot on curve
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 5, height: 5)
                                    .position(
                                        x: x,
                                        y: geo.size.height - h
                                    )
                            }
                        }
                    }
                }
            }
            .frame(height: 80)

            // MARK: Today marker line
            .overlay(alignment: .bottomLeading) {
                GeometryReader { geo in
                    let totalDays = CGFloat(daysInMonth())
                    let todayDay  = CGFloat((dailyData.last?.day ?? 1) - 1)
                    let xPos      = todayDay / (totalDays - 1) * geo.size.width

                    // Vertical dashed line at today
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: xPos)

                    // Grey area = future (remaining days)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.04))
                        .frame(width: geo.size.width - xPos)
                        .offset(x: xPos)
                }
            }

            // MARK: X-axis labels
            GeometryReader { geo in
                let total    = CGFloat(daysInMonth())
                let todayDay = dailyData.last?.day ?? 1
                // Show: 1, ~1/4, ~1/2, ~3/4, today, end
                let labels: [(day: Int, faded: Bool)] = [
                    (1,                   false),
                    (total > 20 ? 8  : 5, false),
                    (total > 20 ? 15 : 10, false),
                    (todayDay,            false),
                    (Int(total),          true)
                ]
                ForEach(labels.filter { $0.day <= Int(total) }, id: \.day) { item in
                    let x = CGFloat(item.day - 1) / (total - 1) * geo.size.width
                    Text(item.day == todayDay ? "↑" : "\(item.day)")
                        .font(.system(size: item.day == todayDay ? 10 : 9))
                        .fontWeight(item.day == todayDay ? .semibold : .regular)
                        .foregroundColor(
                            item.faded ? .secondary.opacity(0.35) :
                            item.day == todayDay ? .blue : .secondary
                        )
                        .position(x: x, y: 6)
                }
            }
            .frame(height: 14)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(
            color: .black.opacity(0.06),
            radius: 12,
            x: 0, y: 4
        )
    }

    // MARK: - Legend Item
    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Curve Path (smooth)
    func curvePath(width: CGFloat, height: CGFloat) -> Path {
        guard dailyData.count > 1 else { return Path() }
        var path = Path()

        let points = curvePoints(width: width, height: height)
        guard let first = points.first else { return path }

        path.move(to: first)

        for i in 1..<points.count {
            let prev    = points[i - 1]
            let current = points[i]
            let midX    = (prev.x + current.x) / 2
            path.addCurve(
                to:      current,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    // MARK: - Fill Shape
    func curveShape(width: CGFloat, height: CGFloat) -> Path {
        var path = curvePath(width: width, height: height)
        guard !path.isEmpty else { return path }

        // Close the shape at the bottom
        path.addLine(to: CGPoint(
            x: xPosition(
                index: dailyData.count - 1,
                width: width
            ),
            y: height
        ))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }

    // MARK: - Curve Points
    func curvePoints(
        width: CGFloat,
        height: CGFloat
    ) -> [CGPoint] {
        dailyData.enumerated().map { index, point in
            CGPoint(
                x: xPosition(index: index, width: width),
                y: height - barHeight(
                    expense:     point.expense,
                    totalHeight: height
                )
            )
        }
    }

    // MARK: - Helpers
    func xPosition(index: Int, width: CGFloat) -> CGFloat {
        guard dailyData.count > 1 else { return 0 }
        // ✅ Scale to actual month progress
        // day 19 of 31 = 61% of width, not 100%
        let totalDays  = CGFloat(daysInMonth())
        let dayWidth   = width / (totalDays - 1)
        // dailyData[0] = day 1, so offset by (day-1)
        let dayNumber  = CGFloat(dailyData[index].day - 1)
        return dayNumber * dayWidth
    }

    func barHeight(
        expense: Double,
        totalHeight: CGFloat
    ) -> CGFloat {
        guard maxExpense > 0 else { return 0 }
        let ratio = expense / maxExpense
        // Min height 2 for non-zero values
        return expense > 0
            ? max(2, totalHeight * 0.85 * CGFloat(ratio))
            : 0
    }

    func monthLabel() -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    func daysInMonth() -> Int {
        let calendar = Calendar.current
        let range    = calendar.range(
            of: .day,
            in: .month,
            for: Date()
        )
        return range?.count ?? 30
    }
}

// MARK: - Data Model
struct DailyExpensePoint: Identifiable {
    let id  = UUID()
    let day: Int
    let expense: Double
}

// MARK: - Preview Helper
extension MonthlyExpenseChartCard {
    static func buildFromCoreData() -> MonthlyExpenseChartCard {
        let calendar = Calendar.current
        let now      = Date()
        let month    = calendar.component(.month, from: now)
        let year     = calendar.component(.year,  from: now)

        // Get days so far this month
        let today    = calendar.component(.day, from: now)
        let coreData = CoreDataManager.shared

        var points: [DailyExpensePoint] = []

        for day in 1...today {
            var comps      = DateComponents()
            comps.year     = year
            comps.month    = month
            comps.day      = day
            let date = calendar.date(from: comps) ?? now

            let formatter        = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr          = formatter.string(from: date)

            let expense = coreData
                .fetchDailySummary(for: dateStr)?
                .totalExpense ?? 0

            points.append(DailyExpensePoint(
                day:     day,
                expense: expense
            ))
        }

        return MonthlyExpenseChartCard(dailyData: points)
    }
}
