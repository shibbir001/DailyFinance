// Views/Auth/LoginView.swift
import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LoginView: View {

    // MARK: - Properties
    @StateObject private var auth = AuthController.shared

    // MARK: - Body
    var body: some View {
        ZStack {
            // MARK: Background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint:   .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // MARK: Logo Section
                logoSection

                Spacer()

                // MARK: Sign In Buttons
                signInSection

                // MARK: Footer
                footerSection
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Logo Section
    var logoSection: some View {
        VStack(spacing: 20) {

            // App Icon
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
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }

            // App Name
            VStack(spacing: 8) {
                Text("DailyFinance")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)

                Text("Track your daily income & expenses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Sign In Section
    var signInSection: some View {
        VStack(spacing: 16) {

            Text("Sign in to continue")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            // MARK: Apple Sign In Button
            Button {
                auth.startAppleSignIn()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Continue with Apple")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(
                    Color(UIColor.systemBackground)
                )
                .cornerRadius(14)
            }
            .disabled(auth.isLoading)

            // MARK: Google Sign In Button
            Button {
                Task {
                    await auth.startGoogleSignIn()
                }
            } label: {
                HStack(spacing: 12) {

                    // Google logo colors
                    GoogleLogoView(size: 24)

                    Text("Continue with Google")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.3),
                                lineWidth: 1.5)
                )
                .shadow(
                    color: .black.opacity(0.06),
                    radius: 8
                )
            }
            .disabled(auth.isLoading)

            // MARK: Loading Indicator
            if auth.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Signing in...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            // MARK: Error Message
            if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Footer
    var footerSection: some View {
        VStack(spacing: 8) {
            Text("By continuing you agree to our")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button("Terms of Service") {}
                    .font(.caption)
                    .foregroundColor(.green)

                Text("and")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Privacy Policy") {}
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Google Logo Component
// Pixel-perfect conversion from official Google SVG
// All control points calculated exactly from SVG path data
struct GoogleLogoView: View {

    var size: CGFloat = 24

    var body: some View {
        Canvas { context, canvasSize in

            // SVG viewBox is 48x48 — scale to canvas
            let s = canvasSize.width / 48.0

            // Shorthand: scale a point
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * s, y: y * s)
            }

            // ── YELLOW (base layer — full shape) ─────
            // Draws the full Google circle shape
            var yellow = Path()
            yellow.move(to: p(43.611, 20.083))
            yellow.addLine(to: p(42, 20.083))
            yellow.addLine(to: p(42, 20))
            yellow.addLine(to: p(24, 20))
            yellow.addLine(to: p(24, 28))
            yellow.addLine(to: p(35.303, 28))
            // curve: c -1.649,4.657 -6.08,8 -11.303,8
            yellow.addCurve(
                to:       p(24, 36),
                control1: p(33.654, 32.657),
                control2: p(29.223, 36))
            // c -6.627,0 -12,-5.373 -12,-12
            yellow.addCurve(
                to:       p(12, 24),
                control1: p(17.373, 36),
                control2: p(12, 30.627))
            // c 0,-6.627 5.373,-12 12,-12
            yellow.addCurve(
                to:       p(24, 12),
                control1: p(12, 17.373),
                control2: p(17.373, 12))
            // c 3.059,0 5.842,1.154 7.961,3.039
            yellow.addCurve(
                to:       p(31.961, 15.039),
                control1: p(27.059, 12),
                control2: p(29.842, 13.154))
            yellow.addLine(to: p(37.618, 9.382))
            // C 34.046,6.053 29.268,4 24,4
            yellow.addCurve(
                to:       p(24, 4),
                control1: p(34.046, 6.053),
                control2: p(29.268, 4))
            // C 12.955,4 4,12.955 4,24
            yellow.addCurve(
                to:       p(4, 24),
                control1: p(12.955, 4),
                control2: p(4, 12.955))
            // c 0,11.045 8.955,20 20,20
            yellow.addCurve(
                to:       p(24, 44),
                control1: p(4, 35.045),
                control2: p(12.955, 44))
            // c 11.045,0 20,-8.955 20,-20
            yellow.addCurve(
                to:       p(44, 24),
                control1: p(35.045, 44),
                control2: p(44, 35.045))
            // C 44,22.659 43.862,21.35 43.611,20.083
            yellow.addCurve(
                to:       p(43.611, 20.083),
                control1: p(44, 22.659),
                control2: p(43.862, 21.35))
            yellow.closeSubpath()
            context.fill(yellow, with: .color(
                Color(red: 1.0, green: 0.753, blue: 0.027)))

            // ── RED (top-left segment) ────────────────
            var red = Path()
            red.move(to: p(6.306, 14.691))
            // l 6.571,4.819
            red.addLine(to: p(12.877, 19.51))
            // C 14.655,15.108 18.961,12 24,12
            red.addCurve(
                to:       p(24, 12),
                control1: p(14.655, 15.108),
                control2: p(18.961, 12))
            // c 3.059,0 5.842,1.154 7.961,3.039
            red.addCurve(
                to:       p(31.961, 15.039),
                control1: p(27.059, 12),
                control2: p(29.842, 13.154))
            // l 5.657,-5.657
            red.addLine(to: p(37.618, 9.382))
            // C 34.046,6.053 29.268,4 24,4
            red.addCurve(
                to:       p(24, 4),
                control1: p(34.046, 6.053),
                control2: p(29.268, 4))
            // C 16.318,4 9.656,8.337 6.306,14.691
            red.addCurve(
                to:       p(6.306, 14.691),
                control1: p(16.318, 4),
                control2: p(9.656, 8.337))
            red.closeSubpath()
            context.fill(red, with: .color(
                Color(red: 1.0, green: 0.239, blue: 0.0)))

            // ── GREEN (bottom segment) ────────────────
            var green = Path()
            green.move(to: p(24, 44))
            // c 5.166,0 9.86,-1.977 13.409,-5.192
            green.addCurve(
                to:       p(37.409, 38.808),
                control1: p(29.166, 44),
                control2: p(33.86, 42.023))
            // l -6.19,-5.238
            green.addLine(to: p(31.219, 33.57))
            // C 29.211,35.091 26.715,36 24,36
            green.addCurve(
                to:       p(24, 36),
                control1: p(29.211, 35.091),
                control2: p(26.715, 36))
            // c -5.202,0 -9.619,-3.317 -11.283,-7.946
            green.addCurve(
                to:       p(12.717, 28.054),
                control1: p(18.798, 36),
                control2: p(14.381, 32.683))
            // l -6.522,5.025
            green.addLine(to: p(6.195, 33.079))
            // C 9.505,39.556 16.227,44 24,44
            green.addCurve(
                to:       p(24, 44),
                control1: p(9.505, 39.556),
                control2: p(16.227, 44))
            green.closeSubpath()
            context.fill(green, with: .color(
                Color(red: 0.298, green: 0.686, blue: 0.314)))

            // ── BLUE (right segment + crossbar) ───────
            // This is drawn LAST so it sits on top
            var blue = Path()
            blue.move(to: p(43.611, 20.083))
            // H 42
            blue.addLine(to: p(42, 20.083))
            // V 20
            blue.addLine(to: p(42, 20))
            // H 24
            blue.addLine(to: p(24, 20))
            // v 8
            blue.addLine(to: p(24, 28))
            // h 11.303
            blue.addLine(to: p(35.303, 28))
            // c -0.792,2.237 -2.231,4.166 -4.087,5.571
            blue.addCurve(
                to:       p(31.216, 33.571),
                control1: p(34.511, 30.237),
                control2: p(33.072, 32.166))
            // c 0.001,-0.001 0.002,-0.001 0.003,-0.002
            // (near-zero movement — skip, treat as line)
            blue.addLine(to: p(31.219, 33.569))
            // l 6.19,5.238
            blue.addLine(to: p(37.409, 38.807))
            // C 36.971,39.205 44,34 44,24
            blue.addCurve(
                to:       p(44, 24),
                control1: p(36.971, 39.205),
                control2: p(44, 34))
            // C 44,22.659 43.862,21.35 43.611,20.083
            blue.addCurve(
                to:       p(43.611, 20.083),
                control1: p(44, 22.659),
                control2: p(43.862, 21.35))
            blue.closeSubpath()
            context.fill(blue, with: .color(
                Color(red: 0.098, green: 0.463, blue: 0.824)))
        }
        .frame(width: size, height: size)
    }
}
