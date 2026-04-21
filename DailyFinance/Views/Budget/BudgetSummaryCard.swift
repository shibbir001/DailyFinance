// Views/Budget/BudgetSummaryCard.swift
import SwiftUI

struct BudgetSummaryCard: View {
    @StateObject private var manager = BudgetManager.shared
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @State private var showBudgets  = false
    @State private var isExpanded   = false

    var hasAlerts: Bool {
        manager.exceededCount > 0 || manager.warningCount > 0
    }

    var body: some View {
        // Only show if budgets are set
        guard !manager.budgetStatuses.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {

                // ── Always-visible header row ──────────────
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        // Status dot
                        Circle()
                            .fill(hasAlerts
                                  ? (manager.exceededCount > 0 ? Color.red : Color.orange)
                                  : theme.accent)
                            .frame(width: 8, height: 8)

                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(hasAlerts
                                             ? (manager.exceededCount > 0 ? .red : .orange)
                                             : theme.accent)
                            .font(.subheadline)

                        Text("Budgets")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        // Summary pill
                        Text(summaryText)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(hasAlerts
                                             ? (manager.exceededCount > 0 ? .red : .orange)
                                             : theme.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                (hasAlerts
                                 ? (manager.exceededCount > 0 ? Color.red : Color.orange)
                                 : theme.accent).opacity(0.1)
                            )
                            .cornerRadius(8)

                        Image(systemName: isExpanded
                              ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                // ── Expandable bars section ────────────────
                if isExpanded {
                    Divider().padding(.horizontal)

                    VStack(spacing: 10) {
                        ForEach(manager.budgetStatuses.prefix(4)) { status in
                            budgetRow(status)
                        }

                        if manager.budgetStatuses.count > 4 {
                            Text("+ \(manager.budgetStatuses.count - 4) more budgets")
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        // Manage button
                        Button {
                            showBudgets = true
                        } label: {
                            Text("Manage Budgets")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(theme.lightBg)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(
                color: hasAlerts
                    ? (manager.exceededCount > 0 ? Color.red : Color.orange).opacity(0.12)
                    : Color.black.opacity(0.05),
                radius: 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        manager.exceededCount > 0 ? Color.red.opacity(0.25)
                            : manager.warningCount > 0 ? Color.orange.opacity(0.25)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .onAppear {
                // Auto-expand if there are alerts
                isExpanded = hasAlerts
            }
            .sheet(isPresented: $showBudgets) {
                BudgetView()
                    .environmentObject(preferences)
                    .environmentObject(theme)
            }
        )
    }

    // MARK: - Budget Row
    func budgetRow(_ status: BudgetStatus) -> some View {
        let color: Color = status.isExceeded ? .red
            : status.isWarning ? .orange
            : theme.accent

        return HStack(spacing: 10) {
            Text(status.icon).font(.caption)
                .frame(width: 20)

            Text(status.label)
                .font(.caption).lineLimit(1)
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: geo.size.width * CGFloat(status.fraction),
                            height: 7
                        )
                        .animation(.spring(), value: status.fraction)
                }
            }
            .frame(height: 7)

            Text(preferences.format(status.spent))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Summary Text
    var summaryText: String {
        if manager.exceededCount > 0 {
            return "\(manager.exceededCount) exceeded"
        } else if manager.warningCount > 0 {
            return "\(manager.warningCount) near limit"
        } else {
            let onTrack = manager.budgetStatuses.count
            return "\(onTrack) on track"
        }
    }
}
