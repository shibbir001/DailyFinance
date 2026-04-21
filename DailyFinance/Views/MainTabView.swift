// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @StateObject private var auth = AuthController.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabContentView(selectedTab: $selectedTab)
                .environmentObject(preferences)
                .environmentObject(theme)

            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Custom Tab Bar
    var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(index: 0, icon: "house.fill",          label: "Dashboard")
            tabItem(index: 1, icon: "clock.fill",          label: "History")
            tabItem(index: 2, icon: "chart.bar.doc.horizontal.fill", label: "Budgets")
            tabItem(index: 3, icon: "chart.bar.fill",      label: "Analysis")
            tabItem(index: 4, icon: "person.fill",         label: "Profile")
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: -4)
        )
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    func tabItem(index: Int, icon: String, label: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.accent.opacity(0.12))
                            .frame(width: 48, height: 32)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? theme.accent : .secondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 32)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tab Content Router
struct TabContentView: View {

    @Binding var selectedTab: Int
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    var body: some View {
        ZStack {
            DashboardContentView()
                .environmentObject(preferences)
                .environmentObject(theme)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)
                // ✅ Reload when switching back to dashboard
                .onChange(of: selectedTab) { tab in
                    if tab == 0 {
                        TransactionController.shared.loadTodayData()
                        BudgetManager.shared.recalculateStatuses()
                    }
                }

            HistoryView()
                .environmentObject(preferences)
                .environmentObject(theme)
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)
                // ✅ Reload when switching to history
                .onChange(of: selectedTab) { tab in
                    if tab == 1 {
                        HistoryController.shared.loadMonthData()
                        HistoryController.shared.loadCalendarData()
                    }
                }

            BudgetView()
                .environmentObject(preferences)
                .environmentObject(theme)
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)
                // ✅ Reload when switching to budgets
                .onChange(of: selectedTab) { tab in
                    if tab == 2 {
                        BudgetManager.shared.loadBudgets()
                    }
                }

            AnalysisView()
                .environmentObject(preferences)
                .environmentObject(theme)
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)

            ProfileView()
                .environmentObject(preferences)
                .environmentObject(theme)
                .opacity(selectedTab == 4 ? 1 : 0)
                .allowsHitTesting(selectedTab == 4)
        }
    }
}
