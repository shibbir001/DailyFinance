//
//  DonutSlice.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Views/Charts/DonutChartView.swift
import SwiftUI

// MARK: - Donut Slice Model
struct DonutSlice: Identifiable {
    let id       = UUID()
    var category: String
    var amount:   Double
    var color:    Color
    var icon:     String
}

// MARK: - Donut Chart View
struct DonutChartView: View {

    var slices:    [DonutSlice]
    var total:     Double
    var title:     String  = "Spending"
    var centerLabel: String = "Total"

    @EnvironmentObject private var preferences: UserPreferences
    @State private var selectedSlice: DonutSlice? = nil
    @State private var animationProgress: Double  = 0

    // Chart geometry
    private let lineWidth:   CGFloat = 32
    private let chartSize:   CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            HStack(alignment: .center, spacing: 20) {

                // ── Donut ──────────────────────────────────
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: lineWidth)
                        .frame(width: chartSize, height: chartSize)

                    // Slices
                    ForEach(Array(sliceAngles.enumerated()), id: \.offset) { i, angles in
                        if i < slices.count {
                            DonutArcShape(
                                startAngle: angles.start,
                                endAngle:   angles.end,
                                lineWidth:  lineWidth
                            )
                            .stroke(
                                slices[i].color,
                                style: StrokeStyle(
                                    lineWidth: selectedSlice?.id == slices[i].id
                                        ? lineWidth + 8 : lineWidth,
                                    lineCap: .butt
                                )
                            )
                            .frame(width: chartSize, height: chartSize)
                            .scaleEffect(selectedSlice?.id == slices[i].id ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: selectedSlice?.id)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    if selectedSlice?.id == slices[i].id {
                                        selectedSlice = nil
                                    } else {
                                        selectedSlice = slices[i]
                                    }
                                }
                            }
                        }
                    }

                    // Center label
                    VStack(spacing: 2) {
                        if let sel = selectedSlice {
                            Text(sel.icon)
                                .font(.title2)
                            Text(sel.category)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(preferences.format(sel.amount))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(sel.color)
                        } else {
                            Text(centerLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(preferences.format(total))
                                .font(.system(size: 14, weight: .bold))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: chartSize - lineWidth * 2 - 16)
                    .animation(.easeInOut(duration: 0.2), value: selectedSlice?.id)
                }
                .frame(width: chartSize, height: chartSize)

                // ── Legend ─────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices.prefix(6)) { slice in
                        Button {
                            withAnimation(.spring()) {
                                selectedSlice = selectedSlice?.id == slice.id ? nil : slice
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(selectedSlice?.id == slice.id ? 1.4 : 1.0)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slice.category)
                                        .font(.caption)
                                        .fontWeight(selectedSlice?.id == slice.id ? .semibold : .regular)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Text(total > 0
                                         ? String(format: "%.1f%%", (slice.amount / total) * 100)
                                         : "0%")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .animation(.spring(response: 0.2), value: selectedSlice?.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
    }

    // Convert slice amounts to start/end angles
    var sliceAngles: [(start: Angle, end: Angle)] {
        guard total > 0 else { return [] }
        var result: [(Angle, Angle)] = []
        var current = -90.0 // Start from top

        for slice in slices {
            let degrees = (slice.amount / total) * 360
            result.append((
                start: .degrees(current),
                end:   .degrees(current + degrees)
            ))
            current += degrees
        }
        return result
    }
}

// MARK: - Donut Arc Shape
struct DonutArcShape: Shape {
    var startAngle: Angle
    var endAngle:   Angle
    var lineWidth:  CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        p.addArc(
            center:     CGPoint(x: rect.midX, y: rect.midY),
            radius:     r,
            startAngle: startAngle,
            endAngle:   endAngle,
            clockwise:  false
        )
        return p
    }
}

// MARK: - Chart Color Palette
extension Color {
    static let chartPalette: [Color] = [
        Color(red: 0.98, green: 0.45, blue: 0.09),  // orange
        Color(red: 0.23, green: 0.51, blue: 0.96),  // blue
        Color(red: 0.66, green: 0.33, blue: 0.97),  // purple
        Color(red: 0.08, green: 0.72, blue: 0.65),  // teal
        Color(red: 0.93, green: 0.28, blue: 0.60),  // pink
        Color(red: 0.13, green: 0.77, blue: 0.37),  // green
        Color(red: 0.92, green: 0.70, blue: 0.03),  // yellow
        Color(red: 0.39, green: 0.40, blue: 0.95),  // indigo
    ]
}