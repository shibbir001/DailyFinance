//
//  WidgetPromptView.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Views/Onboarding/WidgetPromptView.swift
import SwiftUI
import WidgetKit

struct WidgetPromptView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 28) {

            Spacer()

            // Widget preview mockup
            widgetPreview

            // Text
            VStack(spacing: 12) {
                Text("Add Widget to Home Screen")
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("See your daily balance, income and expenses at a glance — without opening the app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Steps
            VStack(alignment: .leading, spacing: 14) {
                stepRow(number: "1", text: "Long press your home screen")
                stepRow(number: "2", text: "Tap the  +  button (top left)")
                stepRow(number: "3", text: "Search for \"DailyFinance\"")
                stepRow(number: "4", text: "Select medium widget → Add")
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    // Mark as shown so it never appears again
                    UserDefaults.standard.set(true, forKey: "widgetPromptShown")
                    dismiss()
                } label: {
                    Text("Got it!")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(theme.accent).cornerRadius(16)
                }

                Button {
                    UserDefaults.standard.set(true, forKey: "widgetPromptShown")
                    dismiss()
                } label: {
                    Text("Maybe later")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - Widget Preview Mockup
    var widgetPreview: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                    Text("DailyFinance")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Text("Today's Balance")
                    .font(.caption2).foregroundColor(.white.opacity(0.75))
                Text("$484.10")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.caption2)
                    Text("Profit").font(.caption2).fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.2)).cornerRadius(20)
                Spacer()
                Text("Saturday, Mar 21")
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
            }
            .padding(.leading, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(.white.opacity(0.25)).frame(width: 0.5).padding(.vertical, 14)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill").font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                        Text("Income").font(.caption2).foregroundColor(.white.opacity(0.75))
                    }
                    Text("$1,054.10")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)

                Rectangle().fill(.white.opacity(0.25)).frame(height: 0.5).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill").font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                        Text("Expense").font(.caption2).foregroundColor(.white.opacity(0.75))
                    }
                    Text("$570.00")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)
            }
            .frame(width: 120)
        }
        .frame(height: 155)
        .frame(width: 330)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.77, blue: 0.37),
                         Color(red: 0.05, green: 0.58, blue: 0.53)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: .green.opacity(0.3), radius: 12)
    }

    // MARK: - Step Row
    func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption).fontWeight(.bold).foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(theme.accent).cornerRadius(12)
            Text(text)
                .font(.subheadline)
        }
    }
}