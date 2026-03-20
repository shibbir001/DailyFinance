// Helpers/ThemeManager.swift
import SwiftUI
import Combine

// MARK: - App Theme Colors
enum AppTheme: String, CaseIterable {
    case green  = "Green"
    case blue   = "Blue"
    case purple = "Purple"
    case orange = "Orange"
    case teal   = "Teal"
    case indigo = "Indigo"

    var accent: Color {
        switch self {
        case .green:  return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .blue:   return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .purple: return Color(red: 0.66, green: 0.33, blue: 0.97)
        case .orange: return Color(red: 0.98, green: 0.45, blue: 0.09)
        case .teal:   return Color(red: 0.08, green: 0.72, blue: 0.65)
        case .indigo: return Color(red: 0.39, green: 0.40, blue: 0.95)
        }
    }

    var lightBg: Color  { accent.opacity(0.07) }
    var mediumBg: Color { accent.opacity(0.13) }

    var gradient: LinearGradient {
        switch self {
        case .green:
            return LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.77, blue: 0.37),
                    Color(red: 0.05, green: 0.58, blue: 0.53)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        case .blue:
            return LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.51, blue: 0.96),
                    Color(red: 0.39, green: 0.40, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.33, blue: 0.97),
                    Color(red: 0.93, green: 0.28, blue: 0.60)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        case .orange:
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.45, blue: 0.09),
                    Color(red: 0.92, green: 0.70, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        case .teal:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.72, blue: 0.65),
                    Color(red: 0.23, green: 0.51, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        case .indigo:
            return LinearGradient(
                colors: [
                    Color(red: 0.39, green: 0.40, blue: 0.95),
                    Color(red: 0.66, green: 0.33, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        }
    }

    var icon: String {
        switch self {
        case .green:  return "leaf.fill"
        case .blue:   return "drop.fill"
        case .purple: return "sparkles"
        case .orange: return "flame.fill"
        case .teal:   return "wind"
        case .indigo: return "moon.stars.fill"
        }
    }
}

// MARK: - Theme Manager
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(
                current.rawValue,
                forKey: "appTheme"
            )
        }
    }

    private init() {
        let saved = UserDefaults.standard
            .string(forKey: "appTheme") ?? AppTheme.green.rawValue
        self.current = AppTheme(rawValue: saved) ?? .green
    }

    var accent:   Color              { current.accent }
    var lightBg:  Color              { current.lightBg }
    var mediumBg: Color              { current.mediumBg }
    var gradient: LinearGradient     { current.gradient }
}
