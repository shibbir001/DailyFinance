// Views/Transaction/AddTransactionView.swift
import SwiftUI

struct AddTransactionView: View {

    // MARK: - Properties
    @StateObject private var controller = TransactionController.shared
    @Environment(\.dismiss) var dismiss

    var defaultType: String = "expense"
    var forDate:     Date   = Date()          // ✅ specific date support

    @EnvironmentObject private var theme: ThemeManager

    // MARK: - State
    @State private var selectedType:       String = "expense"
    @State private var selectedCategory:   String = ""
    @State private var note:               String = ""
    @State private var numpadInput:        String = "0"
    @State private var isAdding:           Bool   = false
    @State private var isNoteActive:       Bool   = false
    @State private var showCategoryPicker: Bool   = false

    // MARK: - Computed
    var categories: [CategoryEntity] {
        selectedType == "income"
            ? controller.incomeCategories
            : controller.expenseCategories
    }

    var amountValue: Double { Double(numpadInput) ?? 0 }

    var isFormValid: Bool { amountValue > 0 && !selectedCategory.isEmpty }

    var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(forDate) {
            return "Today"
        } else if calendar.isDateInYesterday(forDate) {
            return "Yesterday"
        } else {
            let f        = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return f.string(from: forDate)
        }
    }

    // MARK: - Init
    init(defaultType: String = "expense", forDate: Date = Date()) {
        self.defaultType = defaultType
        self.forDate     = forDate
        _selectedType    = State(initialValue: defaultType)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: Type Selector
                    typeSelector.padding()

                    ScrollView {
                        VStack(spacing: 20) {

                            // MARK: Date indicator
                            if !Calendar.current.isDateInToday(forDate) {
                                dateIndicator
                            }

                            // MARK: Amount Display
                            amountDisplay

                            // MARK: Category Picker
                            categoryPicker

                            // MARK: Note Field
                            noteField

                            // MARK: Numpad — hidden when note active
                            if !isNoteActive {
                                numpad
                                    .transition(.move(edge: .bottom)
                                        .combined(with: .opacity))
                            }

                            // MARK: Save Button
                            saveButton

                            Color.clear.frame(height: 30)
                        }
                        .padding(.horizontal)
                    }
                    // ✅ Tap outside note to show numpad again
                    .onTapGesture {
                        if isNoteActive {
                            isNoteActive = false
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                    }
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                // ✅ Done button appears when note is active
                if isNoteActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isNoteActive = false
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    }
                }
            }
            .onAppear {
                // ✅ Works correctly because parent uses
                // .id(transactionType) to force fresh view
                selectedType = defaultType
                controller.loadCategories()
                setDefaultCategory()
            }
            .onChange(of: selectedType) { _ in setDefaultCategory() }
            .onChange(of: controller.incomeCategories) { _ in
                if selectedType == "income" { setDefaultCategory() }
            }
            .onChange(of: controller.expenseCategories) { _ in
                if selectedType == "expense" { setDefaultCategory() }
            }
            .animation(.easeInOut(duration: 0.25), value: isNoteActive)
        }
    }

    // MARK: - Date Indicator
    var dateIndicator: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.orange)
            Text("Adding for: \(dateLabel)")
                .font(.subheadline)
                .foregroundColor(.orange)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Type Selector
    var typeSelector: some View {
        HStack(spacing: 0) {
            ForEach(["income", "expense"], id: \.self) { type in
                Button {
                    withAnimation(.spring()) { selectedType = type }
                } label: {
                    HStack {
                        Image(systemName: type == "income"
                              ? "arrow.down.circle.fill"
                              : "arrow.up.circle.fill")
                        Text(type.capitalized).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedType == type
                        ? (type == "income" ? Color.green : Color.red)
                        : Color.clear
                    )
                    .foregroundColor(selectedType == type ? .white : .secondary)
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
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$").font(.title).foregroundColor(.secondary)
                Text(numpadInput == "0" ? "0.00" : numpadInput)
                    .font(.system(size: 52, weight: .bold))
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
        // ✅ Tapping amount hides keyboard and shows numpad
        .onTapGesture {
            isNoteActive = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    // ✅ Top 5 frequent categories
    var frequentCategories: [CategoryEntity] {
        let all   = categories
        let usage = CoreDataManager.shared
            .fetchCategoryUsage(type: selectedType)
        return all.sorted {
            (usage[$0.name ?? ""] ?? 0) >
            (usage[$1.name ?? ""] ?? 0)
        }.prefix(5).map { $0 }
    }

    // MARK: - Category Picker
    var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Category")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if selectedCategory.isEmpty {
                    Text("select one")
                        .font(.caption).foregroundColor(.red)
                } else {
                    Text("✓ \(selectedCategory)")
                        .font(.caption).foregroundColor(theme.accent)
                }
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
                    .padding(.leading, 8)
                }
            }

            if categories.isEmpty {
                Text("Loading...")
                    .font(.caption).foregroundColor(.secondary)
                    .onAppear { controller.loadCategories() }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // ✅ Top 5 frequent
                        ForEach(frequentCategories, id: \.id) { cat in
                            Button {
                                selectedCategory = cat.name ?? ""
                                isNoteActive = false
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            } label: {
                                VStack(spacing: 3) {
                                    Text(cat.icon ?? "📌")
                                        .font(.title2)
                                    Text(cat.name ?? "")
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
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

                        // ✅ More button
                        Button {
                            showCategoryPicker = true
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(theme.accent)
                                Text("More")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.accent)
                            }
                            .frame(width: 60, height: 60)
                            .background(theme.lightBg)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        theme.accent.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }

                // Show selected if not in frequent list
                if !selectedCategory.isEmpty &&
                   !frequentCategories.contains(where: {
                       $0.name == selectedCategory
                   }) {
                    HStack(spacing: 8) {
                        Text(categories.first {
                            $0.name == selectedCategory
                        }?.icon ?? "📌")
                        Text(selectedCategory)
                            .font(.subheadline)
                            .foregroundColor(theme.accent)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Change") {
                            showCategoryPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(theme.accent)
                    }
                    .padding(10)
                    .background(theme.lightBg)
                    .cornerRadius(10)
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                type:     selectedType,
                selected: $selectedCategory
            )
            .environmentObject(theme)
        }
    }

    // MARK: - Note Field
    var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)").font(.subheadline).fontWeight(.semibold)

            HStack {
                Image(systemName: "note.text").foregroundColor(.secondary)

                // ✅ Custom TextField that tracks focus
                TextField("e.g. Lunch at Subway", text: $note,
                    onEditingChanged: { editing in
                        withAnimation {
                            isNoteActive = editing  // ✅ hide numpad when typing
                        }
                    }
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isNoteActive ? Color.green.opacity(0.5) : Color.clear,
                            lineWidth: 1.5)
            )

            if isNoteActive {
                Text("Tap anywhere or press Done to close keyboard")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Custom Numpad
    var numpad: some View {
        VStack(spacing: 10) {
            let rows: [[String]] = [
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
                [".", "0",  "⌫"]
            ]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleNumpad(key)
                        } label: {
                            Text(key)
                                .font(.title2).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    key == "⌫"
                                    ? Color.orange.opacity(0.15)
                                    : Color(.systemBackground)
                                )
                                .foregroundColor(key == "⌫" ? .orange : .primary)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.05), radius: 4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Save Button
    var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            HStack {
                if isAdding {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Transaction").fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isFormValid
                ? (selectedType == "income" ? Color.green : Color.red)
                : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isFormValid || isAdding)
        .opacity(isFormValid ? 1.0 : 0.5)
    }

    // MARK: - Numpad Logic
    func handleNumpad(_ key: String) {
        switch key {
        case "⌫":
            if numpadInput.count > 1 { numpadInput.removeLast() }
            else { numpadInput = "0" }
        case ".":
            if !numpadInput.contains(".") { numpadInput += "." }
        default:
            if numpadInput == "0" {
                numpadInput = key
            } else {
                if let dotIndex = numpadInput.firstIndex(of: ".") {
                    let decimals = numpadInput.distance(
                        from: dotIndex, to: numpadInput.endIndex)
                    if decimals <= 2 { numpadInput += key }
                } else {
                    if numpadInput.count < 7 { numpadInput += key }
                }
            }
        }
    }

    // MARK: - Save Transaction
    func saveTransaction() {
        guard isFormValid else { return }
        guard !isAdding else { return } // ✅ prevent double save
        isAdding = true

        // ✅ Direct Core Data save (supports forDate)
        _ = CoreDataManager.shared.addTransaction(
            type:     selectedType,
            amount:   amountValue,
            category: selectedCategory,
            note:     note.isEmpty ? selectedCategory : note,
            date:     forDate
        )

        // ✅ Refresh today if adding to today
        TransactionController.shared.loadTodayData()

        // ✅ Real-time sync
        if NetworkMonitor.shared.isConnected {
            Task {
                await SyncService.shared.syncTodayData()
            }
        }

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        isAdding = false
        dismiss()
    }

    // MARK: - Set Default Category
    func setDefaultCategory() {
        let cats = selectedType == "income"
            ? controller.incomeCategories
            : controller.expenseCategories
        if let first = cats.first {
            selectedCategory = first.name ?? ""
        }
    }
}
