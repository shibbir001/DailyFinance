// App/DailyFinanceApp.swift
import SwiftUI
import GoogleSignIn

@main
struct DailyFinanceApp: App {

    // ✅ Connect AppDelegate
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
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isCheckingSession {
                    // ✅ Show splash while checking session
                    // Prevents login screen flash on launch
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
            // ✅ Apply accent color system-wide
            .tint(theme.accent)
            .animation(
                .easeInOut(duration: 0.25),
                value: auth.isCheckingSession
            )
            .animation(
                .easeInOut(duration: 0.25),
                value: auth.isLoggedIn
            )
        }
    }
}
