//
//  TrendPoint.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Views/Charts/SavingsTrendChart.swift
import SwiftUI

// MARK: - Trend Data Point
struct TrendPoint: Identifiable {
    let id        = UUID()
    var label:    String   // "Jan", "Feb" etc.
    var income:   Double
    var expense:  Double
    var net:      Double   // cumulative net
    var month:    Int
    var year:     Int
}

// MARK: - Savings Trend Chart
struct SavingsTrendChart: View {

    var points: [TrendPoint]

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @State private var selectedIndex: Int?      = nil
    @State private var animationProgress: CGFloat = 0

    private let chartHeight: CGFloat = 160
    private let dotRadius:   CGFloat = 5

    var minNet: Double { points.map { $0.net }.min() ?? 0 }
    var maxNet: Double { points.map { $0.net }.max() ?? 1 }
    var netRange: Double { max(maxNet - minNet, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Savings Trend")
                        .font(.headline).fontWeight(.bold)
                    Text("Cumulative net balance over time")
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()

                // Selected point info
                if let idx = selectedIndex, idx < points.count {
                    let pt = points[idx]
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(pt.label)
                            .font(.caption).foregroundColor(.secondary)
                        Text(preferences.format(pt.net))
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(pt.net >= 0 ? theme.accent : .red)
                    }
                    .transition(.opacity)
                }
            }

            // Chart
            GeometryReader { geo in
                let w = geo.size.width
                let h = chartHeight

                ZStack(alignment: .leading) {

                    // Zero line (if min < 0)
                    if minNet < 0 {
                        let zeroY = yPosition(for: 0, in: h)
                        Path { p in
                            p.move(to:    CGPoint(x: 0, y: zeroY))
                            p.addLine(to: CGPoint(x: w, y: zeroY))
                        }
                        .stroke(Color.secondary.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    // Gradient fill under line
                    lineFillPath(width: w, height: h)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.25),
                                    theme.accent.opacity(0.0)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(
                            Rectangle().path(
                                in: CGRect(x: 0, y: 0,
                                           width: w * animationProgress,
                                           height: h + 20)
                            )
                        )

                    // Line
                    linePath(width: w, height: h)
                        .trim(from: 0, to: animationProgress)
                        .stroke(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    // Dots + tap targets
                    ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                        let x = xPosition(for: i, totalCount: points.count, width: w)
                        let y = yPosition(for: pt.net, in: h)
                        let isSelected = selectedIndex == i

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(theme.accent.opacity(0.2))
                                    .frame(width: 20, height: 20)
                            }
                            Circle()
                                .fill(pt.net >= 0 ? theme.accent : Color.red)
                                .frame(width: isSelected ? dotRadius * 2.5 : dotRadius * 2,
                                       height: isSelected ? dotRadius * 2.5 : dotRadius * 2)
                                .overlay(
                                    Circle().stroke(Color(.systemBackground), lineWidth: 2)
                                )
                        }
                        .position(x: x, y: y)
                        .animation(.spring(response: 0.3), value: isSelected)
                        .onTapGesture {
                            withAnimation { selectedIndex = selectedIndex == i ? nil : i }
                        }

                        // Tooltip above selected dot
                        if isSelected {
                            VStack(spacing: 2) {
                                Text(preferences.format(pt.net))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(pt.net >= 0 ? theme.accent : Color.red)
                                    .cornerRadius(6)
                                Triangle()
                                    .fill(pt.net >= 0 ? theme.accent : Color.red)
                                    .frame(width: 8, height: 5)
                            }
                            .position(x: min(max(x, 40), w - 40), y: max(y - 28, 16))
                            .transition(.opacity.combined(with: .scale))
                        }
                    }

                    // Horizontal grid lines
                    ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                        Path { p in
                            let y = h * fraction
                            p.move(to:    CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                    }
                }
                .frame(height: h)
            }
            .frame(height: chartHeight)

            // Month labels
            HStack(spacing: 0) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                    Text(pt.label)
                        .font(.system(size: 9))
                        .foregroundColor(selectedIndex == i ? theme.accent : .secondary)
                        .fontWeight(selectedIndex == i ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                }
            }

            // Summary row
            HStack(spacing: 0) {
                summaryPill(
                    label: "Peak",
                    value: preferences.format(maxNet),
                    color: theme.accent
                )
                Spacer()
                summaryPill(
                    label: "Low",
                    value: preferences.format(minNet),
                    color: minNet < 0 ? .red : theme.accent
                )
                Spacer()
                summaryPill(
                    label: "Trend",
                    value: trendArrow,
                    color: trendColor
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animationProgress = 1
            }
        }
    }

    // MARK: - Helpers
    func xPosition(for index: Int, totalCount: Int, width: CGFloat) -> CGFloat {
        guard totalCount > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(totalCount - 1)
    }

    func yPosition(for value: Double, in height: CGFloat) -> CGFloat {
        let normalised = (value - minNet) / netRange
        return height - CGFloat(normalised) * height * 0.85 - height * 0.075
    }

    func linePath(width: CGFloat, height: CGFloat) -> Path {
        guard points.count > 1 else { return Path() }
        var path = Path()
        for (i, pt) in points.enumerated() {
            let x = xPosition(for: i, totalCount: points.count, width: width)
            let y = yPosition(for: pt.net, in: height)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else {
                let prevX = xPosition(for: i-1, totalCount: points.count, width: width)
                let prevY = yPosition(for: points[i-1].net, in: height)
                let cp1   = CGPoint(x: (prevX + x) / 2, y: prevY)
                let cp2   = CGPoint(x: (prevX + x) / 2, y: y)
                path.addCurve(to: CGPoint(x: x, y: y),
                              control1: cp1, control2: cp2)
            }
        }
        return path
    }

    func lineFillPath(width: CGFloat, height: CGFloat) -> Path {
        guard points.count > 1 else { return Path() }
        var path = linePath(width: width, height: height)
        let lastX = xPosition(for: points.count - 1, totalCount: points.count, width: width)
        path.addLine(to: CGPoint(x: lastX, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }

    func summaryPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
    }

    var trendArrow: String {
        guard points.count >= 2 else { return "→" }
        let diff = (points.last?.net ?? 0) - (points.first?.net ?? 0)
        return diff > 0 ? "↗ Up" : diff < 0 ? "↘ Down" : "→ Flat"
    }

    var trendColor: Color {
        guard points.count >= 2 else { return .secondary }
        let diff = (points.last?.net ?? 0) - (points.first?.net ?? 0)
        return diff > 0 ? .green : diff < 0 ? .red : .secondary
    }
}

// MARK: - Triangle shape (tooltip arrow)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}