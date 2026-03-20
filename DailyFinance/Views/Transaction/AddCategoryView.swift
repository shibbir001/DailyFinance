//
//  AddCategoryView.swift
//  DailyFinance
//
//  Created by Shibbir on 19/3/26.
//


// Views/Transaction/AddCategoryView.swift
import SwiftUI

struct AddCategoryView: View {

    let type: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: ThemeManager

    @State private var name       = ""
    @State private var icon       = "⭐️"
    @State private var showPicker = false

    // Icon palette
    let icons = [
        "⭐️","🔥","💎","🌟","🎪","🎭","🎨","🎯",
        "🏆","🥇","🎸","🎹","🎺","🎻","🥁","🎤",
        "🌈","🦋","🌺","🍀","🌙","☀️","⚡️","❄️",
        "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼",
        "🍕","🍔","🍟","🌮","🍜","🍱","🍣","🧁",
        "🚀","🛸","🚂","🚁","⛵️","🏎️","🚲","🛹",
        "💻","📱","🎮","📷","🔭","🔬","💡","🔋",
        "🏠","🏰","🗼","⛺️","🏖️","🗻","🌋","🏝️",
        "💰","💳","🏦","📈","💹","🪙","💸","🤑",
        "❤️","🧡","💛","💚","💙","💜","🖤","🤍",
    ]

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Preview
                VStack(spacing: 8) {
                    Text(icon)
                        .font(.system(size: 60))
                    Text(name.isEmpty ? "Category Name" : name)
                        .font(.headline)
                        .foregroundColor(name.isEmpty ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(theme.lightBg)
                .cornerRadius(16)
                .padding(.horizontal)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    TextField("e.g. Weekend Fun", text: $name)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: Array(
                            repeating: .init(.flexible()),
                            count: 8
                        ),
                        spacing: 8
                    ) {
                        ForEach(icons, id: \.self) { emoji in
                            Button {
                                withAnimation(.spring(
                                    response: 0.2,
                                    dampingFraction: 0.6
                                )) {
                                    icon = emoji
                                }
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        icon == emoji
                                        ? theme.accent.opacity(0.15)
                                        : Color(.systemBackground)
                                    )
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(
                                                icon == emoji
                                                ? theme.accent : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .scaleEffect(icon == emoji ? 1.15 : 1.0)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Save button
                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    _ = CoreDataManager.shared.addCustomCategory(
                        name:  trimmed,
                        type:  type,
                        icon:  icon,
                        color: "#6366F1"
                    )
                    dismiss()
                } label: {
                    Text("Add Category")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? theme.accent : Color.gray)
                        .cornerRadius(16)
                        .padding(.horizontal)
                }
                .disabled(!isValid)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}