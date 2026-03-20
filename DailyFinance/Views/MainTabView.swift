// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {

    // MARK: - Properties
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    @StateObject private var auth = AuthController.shared
    @State private var selectedTab: Int = 0

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: Tab Content
            TabContentView(selectedTab: $selectedTab)
                .environmentObject(preferences)
                .environmentObject(theme)

            // MARK: Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Custom Tab Bar
    var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(
                index:       0,
                icon:        "house.fill",
                activeIcon:  "house.fill",
                label:       "Dashboard"
            )
            tabItem(
                index:       1,
                icon:        "clock",
                activeIcon:  "clock.fill",
                label:       "History"
            )
            tabItem(
                index:       2,
                icon:        "chart.bar",
                activeIcon:  "chart.bar.fill",
                label:       "Analysis"
            )
            tabItem(
                index:       3,
                icon:        "person",
                activeIcon:  "person.fill",
                label:       "Profile"
            )
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            // Frosted glass effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 20, x: 0, y: -4
                )
        )
        .overlay(
            // Top border line
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Tab Item
    func tabItem(
        index:      Int,
        icon:       String,
        activeIcon: String,
        label:      String
    ) -> some View {
        let isSelected = selectedTab == index

        return Button {
            withAnimation(.spring(
                response:        0.3,
                dampingFraction: 0.7
            )) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Active background pill
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.accent.opacity(0.12))
                            .frame(width: 48, height: 32)
                            .transition(.scale.combined(
                                with: .opacity))
                    }

                    Image(systemName: isSelected
                          ? activeIcon : icon)
                        .font(.system(
                            size: 20,
                            weight: isSelected ? .semibold : .regular
                        ))
                        .foregroundColor(
                            isSelected ? theme.accent : .secondary
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 32)

                Text(label)
                    .font(.system(size: 10, weight: isSelected
                                  ? .semibold : .regular))
                    .foregroundColor(
                        isSelected ? theme.accent : .secondary
                    )
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
            // ✅ Keep all views alive — no reload on switch
            DashboardContentView()
                .environmentObject(preferences)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            HistoryView()
                .environmentObject(preferences)
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

            AnalysisView()
                .environmentObject(preferences)
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

            ProfileView()
                .environmentObject(preferences)
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)
        }
    }
}
