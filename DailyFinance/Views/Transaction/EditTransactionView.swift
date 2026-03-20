// Views/Transaction/EditTransactionView.swift
import SwiftUI
internal import CoreData

struct EditTransactionView: View {

    let transaction: TransactionEntity
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme:       ThemeManager
    @EnvironmentObject var preferences: UserPreferences

    @State private var selectedType:       String = "expense"
    @State private var selectedCategory:   String = ""
    @State private var note:               String = ""
    @State private var amountText:         String = "0"
    @State private var showDeleteAlert:    Bool   = false
    @State private var showCategoryPicker: Bool   = false
    @State private var isNoteActive:       Bool   = false

    private let coreData   = CoreDataManager.shared
    private let controller = TransactionController.shared

    var amountValue: Double { Double(amountText) ?? 0 }
    var isValid: Bool { amountValue > 0 && !selectedCategory.isEmpty }

    var categories: [CategoryEntity] {
        coreData.fetchCategories(type: selectedType)
    }

    var frequentCategories: [CategoryEntity] {
        let usage = coreData.fetchCategoryUsage(type: selectedType)
        return categories.sorted {
            (usage[$0.name ?? ""] ?? 0) >
            (usage[$1.name ?? ""] ?? 0)
        }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Type selector
                    typeSelector

                    // Amount
                    amountDisplay

                    // Category
                    categoryPicker

                    // Note
                    noteField

                    // Numpad
                    if !isNoteActive { numpad }

                    // Delete button
                    deleteButton

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(isValid ? theme.accent : .gray)
                        .disabled(!isValid)
                }
            }
            .onAppear { loadTransaction() }
            .alert("Delete Transaction", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteTransaction()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure? This cannot be undone.")
            }
        }
    }

    // MARK: - Type Selector
    var typeSelector: some View {
        HStack(spacing: 0) {
            ForEach(["income", "expense"], id: \.self) { t in
                Button {
                    withAnimation(.spring()) { selectedType = t }
                    selectedCategory = ""
                } label: {
                    HStack {
                        Image(systemName: t == "income"
                              ? "arrow.down.circle.fill"
                              : "arrow.up.circle.fill")
                        Text(t.capitalized).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedType == t
                        ? (t == "income" ? Color.green : Color.red)
                        : Color.clear
                    )
                    .foregroundColor(
                        selectedType == t ? .white : .secondary
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    // MARK: - Amount Display
    var amountDisplay: some View {
        VStack(spacing: 6) {
            Text("Amount")
                .font(.caption).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(preferences.currency == "GBP" ? "£"
                     : preferences.currency == "EUR" ? "€" : "$")
                    .font(.title).foregroundColor(.secondary)
                Text(amountText == "0" ? "0.00" : amountText)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(selectedType == "income" ? .green : .red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Category Picker
    var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Category").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Text("All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(theme.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(frequentCategories, id: \.id) { cat in
                        Button {
                            selectedCategory = cat.name ?? ""
                        } label: {
                            VStack(spacing: 3) {
                                Text(cat.icon ?? "📌").font(.title2)
                                Text(cat.name ?? "")
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                selectedCategory == cat.name
                                ? theme.accent.opacity(0.15)
                                : Color(.systemBackground)
                            )
                            .foregroundColor(
                                selectedCategory == cat.name
                                ? theme.accent : .primary
                            )
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        selectedCategory == cat.name
                                        ? theme.accent
                                        : Color.secondary.opacity(0.2),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                    }
                    Button {
                        showCategoryPicker = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(theme.accent)
                            Text("More").font(.system(size: 10))
                                .foregroundColor(theme.accent)
                        }
                        .frame(width: 60, height: 60)
                        .background(theme.lightBg)
                        .cornerRadius(14)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                type: selectedType,
                selected: $selectedCategory
            )
            .environmentObject(theme)
        }
    }

    // MARK: - Note Field
    var noteField: some View {
        HStack {
            Image(systemName: "note.text").foregroundColor(.secondary)
            TextField("Note (optional)", text: $note)
                .onTapGesture { isNoteActive = true }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Numpad
    var numpad: some View {
        let keys = [
            ["7","8","9"],
            ["4","5","6"],
            ["1","2","3"],
            [".","0","⌫"]
        ]
        return VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.title2).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Delete Button
    var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Transaction")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.08))
            .cornerRadius(16)
        }
    }

    // MARK: - Actions
    func loadTransaction() {
        selectedType     = transaction.type     ?? "expense"
        selectedCategory = transaction.category ?? ""
        note             = transaction.note     ?? ""
        amountText       = String(transaction.amount)
    }

    func saveChanges() {
        guard isValid else { return }

        let oldDate   = transaction.date ?? Date()
        let oldType   = transaction.type ?? "expense"
        let oldAmount = transaction.amount

        // ✅ Use LOCAL date string (not UTC)
        // transaction.date is UTC — convert to local for summary lookup
        let fmt          = DateFormatter()
        fmt.dateFormat   = "yyyy-MM-dd"
        fmt.timeZone     = TimeZone.current  // ← local timezone!
        let dateStr      = fmt.string(from: oldDate)

        print("🔧 Editing transaction:")
        print("   date=\(oldDate) → dateStr=\(dateStr)")
        print("   old: \(oldType) \(oldAmount)")
        print("   new: \(selectedType) \(amountValue)")

        // ✅ Fetch summary ONCE and update directly
        if let summary = coreData.fetchDailySummary(for: dateStr) {
            print("   Found summary: income=\(summary.totalIncome) expense=\(summary.totalExpense)")

            // Remove old amount
            if oldType == "income" {
                summary.totalIncome = max(0, summary.totalIncome - oldAmount)
            } else {
                summary.totalExpense = max(0, summary.totalExpense - oldAmount)
            }

            // Add new amount
            if selectedType == "income" {
                summary.totalIncome += amountValue
            } else {
                summary.totalExpense += amountValue
            }

            summary.netBalance = summary.totalIncome - summary.totalExpense
            summary.isSynced   = false
            coreData.save()

            print("✅ Summary after edit: income=\(summary.totalIncome) expense=\(summary.totalExpense) net=\(summary.netBalance)")
        } else {
            print("❌ No summary found for \(dateStr)!")
        }

        // ✅ Update transaction
        transaction.type     = selectedType
        transaction.amount   = amountValue
        transaction.category = selectedCategory
        transaction.note     = note.isEmpty ? selectedCategory : note
        transaction.isSynced = false
        coreData.save()

        // ✅ Sync to Supabase in background
        if NetworkMonitor.shared.isConnected {
            Task { await SyncService.shared.syncTodayData() }
        }

        // ✅ Dismiss first, then reload
        // This ensures sheet is gone before UI updates
        dismiss()

        // ✅ Reload after a tiny delay (after dismiss animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            TransactionController.shared.loadTodayData()
            HistoryController.shared.loadMonthData()
            HistoryController.shared.loadCalendarData()
            NotificationCenter.default.post(
                name: NSNotification.Name("TransactionEdited"),
                object: nil
            )
        }
    }

    func deleteTransaction() {
        coreData.deleteTransactionSmart(transaction)
        if NetworkMonitor.shared.isConnected {
            Task { await SyncService.shared.syncTodayData() }
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            TransactionController.shared.loadTodayData()
            HistoryController.shared.loadMonthData()
            HistoryController.shared.loadCalendarData()
            NotificationCenter.default.post(
                name: NSNotification.Name("TransactionEdited"),
                object: nil
            )
        }
    }

    func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if amountText.count > 1 {
                amountText.removeLast()
            } else {
                amountText = "0"
            }
        case ".":
            if !amountText.contains(".") {
                amountText += "."
            }
        default:
            if amountText == "0" {
                amountText = key
            } else if amountText.count < 10 {
                amountText += key
            }
        }
    }
}
