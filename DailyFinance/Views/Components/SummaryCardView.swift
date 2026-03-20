// Views/Components/SummaryCardView.swift
import SwiftUI

struct SummaryCardView: View {

    var title:  String
    var amount: Double
    var icon:   String
    var color:  Color

    // ✅ Reads currency from shared preferences
    @EnvironmentObject private var preferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ✅ Uses preferences.format() — updates live!
            Text(preferences.format(amount))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}
