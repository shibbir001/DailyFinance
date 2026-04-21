// App/DailyFinanceApp.swift
import SwiftUI
import GoogleSignIn

@main
struct DailyFinanceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @StateObject private var auth        = AuthController.shared
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var theme       = ThemeManager.shared

    init() {
        // Configure Google Sign In
        GIDSignIn.sharedInstance.configuration =
            GIDConfiguration(
                clientID: "87769795466-vaj3fonb6bdm7lfvqbn9t9dui6dr1hp9.apps.googleusercontent.com"
            )

        // Setup default categories
        let cd = CoreDataManager.shared
        if !cd.categoriesExist() {
            cd.addDefaultCategories()
        }

        // ✅ Pre-warm categories and usage cache on launch
        // so AddTransactionView shows instantly with no "Loading..."
        Task.detached(priority: .background) {
            let controller = TransactionController.shared
            await MainActor.run {
                controller.loadCategories()
            }
            // Pre-fetch usage stats in background
            // Result is cached in CoreData's in-memory context
            _ = CoreDataManager.shared.fetchCategoryUsage(type: "expense")
            _ = CoreDataManager.shared.fetchCategoryUsage(type: "income")
            print("✅ Category cache warmed")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isCheckingSession {
                    SplashView()
                } else if auth.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(preferences)
            .environmentObject(theme)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .tint(theme.accent)
            .animation(.easeInOut(duration: 0.25), value: auth.isCheckingSession)
            .animation(.easeInOut(duration: 0.25), value: auth.isLoggedIn)
        }
    }
}
