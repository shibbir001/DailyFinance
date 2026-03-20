// Views/SplashView.swift
import SwiftUI

struct SplashView: View {

    @State private var scale:   CGFloat = 0.8
    @State private var opacity: Double  = 0.0

    var body: some View {
        ZStack {
            // ✅ Same background as login
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint:   .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {

                // App icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: .green.opacity(0.4),
                            radius: 20
                        )

                    Text("$")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Text("DailyFinance")
                    .font(.system(size: 34, weight: .bold))
                    .opacity(opacity)

                // Loading indicator
                ProgressView()
                    .tint(.green)
                    .scaleEffect(1.2)
                    .opacity(opacity)
                    .padding(.top, 10)

                // iCloud sync hint
                if CoreDataManager.iCloudEnabledAtLaunch {
                    Text("Restoring your data from iCloud...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(
                response: 0.5,
                dampingFraction: 0.7
            )) {
                scale   = 1.0
                opacity = 1.0
            }
        }
    }
}
