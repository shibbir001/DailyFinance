// Views/Budget/BudgetView.swift
import SwiftUI

struct BudgetView: View {

    @StateObject private var manager = BudgetManager.shared
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    @State private var showAddBudget   = false
    @State private var editingStatus:  BudgetStatus? = nil
    @State private var showDeleteAlert = false
    @State private var deleteID:       UUID? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        overallSummary
                        if manager.budgetStatuses.isEmpty {
                            emptyState
                        } else {
                            budgetList
                        }
                        addButton
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { manager.loadBudgets() }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetSheet(usedCategories: usedCategories)
                    .environmentObject(preferences)
                    .environmentObject(theme)
            }
            .sheet(item: $editingStatus) { status in
                EditBudgetSheet(status: status)
                    .environmentObject(preferences)
                    .environmentObject(theme)
            }
            .alert("Delete Budget", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let id = deleteID { manager.deleteBudget(id: id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove this budget limit?")
            }
        }
    }

    // MARK: - Overall Summary
    var overallSummary: some View {
        let exceeded = manager.exceededCount
        let warning  = manager.warningCount
        let total    = manager.budgetStatuses.count

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(exceeded > 0
                         ? "\(exceeded) Budget\(exceeded > 1 ? "s" : "") Exceeded"
                         : warning > 0
                            ? "\(warning) Near Limit"
                            : "All Budgets On Track")
                        .font(.title3).fontWeight(.bold).foregroundColor(.white)
                }
                Spacer()
                Image(systemName: exceeded > 0
                      ? "exclamationmark.triangle.fill"
                      : warning > 0 ? "exclamationmark.circle.fill"
                      : "checkmark.circle.fill")
                    .font(.title).foregroundColor(.white)
            }

            if total > 0 {
                let safeFraction = Double(total - exceeded - warning) / Double(total)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.3)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: geo.size.width * CGFloat(safeFraction), height: 10)
                            .animation(.spring(), value: safeFraction)
                    }
                }.frame(height: 10)

                HStack {
                    Label("\(total - exceeded - warning) safe", systemImage: "checkmark")
                    Spacer()
                    if warning  > 0 { Label("\(warning) warning",  systemImage: "exclamationmark") }
                    if exceeded > 0 { Label("\(exceeded) over",     systemImage: "xmark") }
                }
                .font(.caption2).foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(20)
        .background(LinearGradient(
            colors: exceeded > 0 ? [Color.red, Color.orange]
                : warning > 0   ? [Color.orange, Color.yellow.opacity(0.8)]
                : [theme.accent, theme.accent.opacity(0.6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .cornerRadius(20)
        .shadow(color: exceeded > 0 ? .red.opacity(0.3) : theme.accent.opacity(0.3), radius: 12)
    }

    // MARK: - Budget List
    var budgetList: some View {
        VStack(spacing: 12) {
            ForEach(manager.budgetStatuses) { status in
                BudgetCard(status: status)
                    .environmentObject(preferences)
                    .environmentObject(theme)
                    .onTapGesture { editingStatus = status }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteID       = status.budget.id
                            showDeleteAlert = true
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingStatus = status } label: {
                            Label("Edit", systemImage: "pencil")
                        }.tint(.blue)
                    }
            }
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48)).foregroundColor(.secondary)
            Text("No Budgets Yet").font(.headline).fontWeight(.bold)
            Text("Set monthly spending limits per category or a total monthly budget.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Add Button
    var addButton: some View {
        Button { showAddBudget = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Budget").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding()
            .background(theme.accent).foregroundColor(.white)
            .cornerRadius(16).shadow(color: theme.accent.opacity(0.3), radius: 8)
        }
    }

    var usedCategories: Set<String> {
        Set(manager.budgets.map { $0.category })
    }
}

// MARK: - Budget Card
struct BudgetCard: View {
    var status: BudgetStatus
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    var statusColor: Color {
        status.isExceeded ? .red : status.isWarning ? .orange : theme.accent
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    Text(status.icon).font(.title2)
                        .frame(width: 40, height: 40)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.label).font(.subheadline).fontWeight(.semibold)
                        Text(status.isExceeded
                             ? "Exceeded by \(preferences.format(status.spent - status.limit))"
                             : status.isWarning ? "\(Int(status.fraction * 100))% used"
                             : "\(preferences.format(status.remaining)) remaining")
                            .font(.caption)
                            .foregroundColor(status.isExceeded ? .red : status.isWarning ? .orange : .secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(preferences.format(status.spent))
                        .font(.subheadline).fontWeight(.bold).foregroundColor(statusColor)
                    Text("of \(preferences.format(status.limit))")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor.opacity(0.15)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: status.isExceeded ? [.red, .orange]
                                : status.isWarning    ? [.orange, .yellow]
                                : [theme.accent, theme.accent.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(status.fraction), height: 10)
                        .animation(.spring(), value: status.fraction)
                }
            }.frame(height: 10)

            HStack {
                Label(
                    status.isExceeded ? "Over budget"
                        : status.isWarning ? "Approaching limit" : "On track",
                    systemImage: status.isExceeded ? "xmark.circle.fill"
                        : status.isWarning ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption2).foregroundColor(statusColor)
                Spacer()
                Text("Tap to edit").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: statusColor.opacity(0.1), radius: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(status.isExceeded ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Add Budget Sheet
struct AddBudgetSheet: View {
    var usedCategories: Set<String>
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    @State private var selectedCategory: String = ""
    @State private var amountText:       String = "0"
    @State private var isTotal:          Bool   = false

    var amountValue: Double { Double(amountText) ?? 0 }
    var isValid: Bool { amountValue > 0 && (isTotal || !selectedCategory.isEmpty) }

    var availableCategories: [CategoryEntity] {
        CoreDataManager.shared.fetchCategories(type: "expense")
            .filter { !usedCategories.contains($0.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Type toggle
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Budget Type").font(.headline).fontWeight(.bold)
                        HStack(spacing: 12) {
                            typeButton(title: "Category", subtitle: "Limit one category",
                                       icon: "tag.fill", selected: !isTotal) {
                                isTotal = false
                            }
                            typeButton(title: "Total", subtitle: "Limit all spending",
                                       icon: "chart.pie.fill", selected: isTotal) {
                                isTotal = true; selectedCategory = ""
                            }
                        }
                    }
                    .padding().background(Color(.systemBackground))
                    .cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 8)

                    // Category grid
                    if !isTotal {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category").font(.headline).fontWeight(.bold)
                            if availableCategories.isEmpty {
                                Text("All categories already have budgets")
                                    .font(.subheadline).foregroundColor(.secondary)
                            } else {
                                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                                    ForEach(availableCategories, id: \.id) { cat in
                                        Button { selectedCategory = cat.name ?? "" } label: {
                                            VStack(spacing: 4) {
                                                Text(cat.icon ?? "💳").font(.title2)
                                                Text(cat.name ?? "").font(.system(size: 10)).lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(selectedCategory == cat.name
                                                        ? theme.accent.opacity(0.15)
                                                        : Color(.systemGroupedBackground))
                                            .foregroundColor(selectedCategory == cat.name ? theme.accent : .primary)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(selectedCategory == cat.name
                                                              ? theme.accent : Color.clear, lineWidth: 1.5))
                                        }
                                    }
                                }
                            }
                        }
                        .padding().background(Color(.systemBackground))
                        .cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 8)
                    }

                    amountSection

                    Button {
                        BudgetManager.shared.addBudget(
                            category:     isTotal ? "" : selectedCategory,
                            monthlyLimit: amountValue
                        )
                        dismiss()
                    } label: {
                        Text("Set Budget").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(isValid ? theme.accent : Color.gray).cornerRadius(16)
                    }.disabled(!isValid)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Budget").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
            }
        }
    }

    func typeButton(title: String, subtitle: String, icon: String,
                    selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                    .foregroundColor(selected ? theme.accent : .secondary)
                Text(title).font(.caption).fontWeight(.semibold)
                    .foregroundColor(selected ? theme.accent : .primary)
                Text(subtitle).font(.system(size: 9)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(selected ? theme.accent.opacity(0.1) : Color(.systemGroupedBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? theme.accent : Color.clear, lineWidth: 1.5))
        }
    }

    var amountSection: some View {
        VStack(spacing: 12) {
            Text("Monthly Limit").font(.headline).fontWeight(.bold)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(preferences.symbol).font(.title).foregroundColor(.secondary)
                Text(amountText == "0" ? "0.00" : amountText)
                    .font(.system(size: 48, weight: .bold)).foregroundColor(theme.accent)
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
            HStack(spacing: 8) {
                ForEach([100, 200, 500, 1000], id: \.self) { val in
                    Button { amountText = String(val) } label: {
                        Text("\(preferences.symbol)\(val)").font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(theme.lightBg).foregroundColor(theme.accent).cornerRadius(20)
                    }
                }
            }
            numpad
        }
        .padding().background(Color(.systemBackground))
        .cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 8)
    }

    var numpad: some View {
        VStack(spacing: 8) {
            ForEach([["7","8","9"],["4","5","6"],["1","2","3"],[".","0","⌫"]], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button { handleKey(key) } label: {
                            Text(key).font(.title2).fontWeight(.medium)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(Color(.systemBackground)).cornerRadius(12)
                        }.foregroundColor(.primary)
                    }
                }
            }
        }
    }

    func handleKey(_ key: String) {
        switch key {
        case "⌫": amountText = amountText.count > 1 ? String(amountText.dropLast()) : "0"
        case ".":  if !amountText.contains(".") { amountText += "." }
        default:   amountText = amountText == "0" ? key : amountText.count < 9 ? amountText + key : amountText
        }
    }
}

// MARK: - Edit Budget Sheet
struct EditBudgetSheet: View {
    var status: BudgetStatus
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    @State private var amountText:      String = "0"
    @State private var showDeleteAlert: Bool   = false

    var amountValue: Double { Double(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(status.icon).font(.system(size: 52))
                        Text(status.label).font(.title3).fontWeight(.bold)
                        Text("Current: \(preferences.format(status.limit))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(theme.lightBg).cornerRadius(16)

                    VStack(spacing: 12) {
                        Text("New Monthly Limit").font(.headline).fontWeight(.bold)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(preferences.symbol).font(.title).foregroundColor(.secondary)
                            Text(amountText == "0" ? "0.00" : amountText)
                                .font(.system(size: 48, weight: .bold)).foregroundColor(theme.accent)
                                .minimumScaleFactor(0.5).lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            ForEach([100, 200, 500, 1000], id: \.self) { val in
                                Button { amountText = String(val) } label: {
                                    Text("\(preferences.symbol)\(val)").font(.caption).fontWeight(.semibold)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(theme.lightBg).foregroundColor(theme.accent).cornerRadius(20)
                                }
                            }
                        }
                        VStack(spacing: 8) {
                            ForEach([["7","8","9"],["4","5","6"],["1","2","3"],[".","0","⌫"]], id: \.self) { row in
                                HStack(spacing: 8) {
                                    ForEach(row, id: \.self) { key in
                                        Button { handleKey(key) } label: {
                                            Text(key).font(.title2).fontWeight(.medium)
                                                .frame(maxWidth: .infinity).frame(height: 48)
                                                .background(Color(.systemBackground)).cornerRadius(12)
                                        }.foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                    .padding().background(Color(.systemBackground))
                    .cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 8)

                    Button {
                        BudgetManager.shared.updateBudget(id: status.budget.id, monthlyLimit: amountValue)
                        dismiss()
                    } label: {
                        Text("Update Budget").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(amountValue > 0 ? theme.accent : Color.gray).cornerRadius(16)
                    }.disabled(amountValue <= 0)

                    Button { showDeleteAlert = true } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Budget").fontWeight(.semibold)
                        }
                        .foregroundColor(.red).frame(maxWidth: .infinity).padding()
                        .background(Color.red.opacity(0.08)).cornerRadius(16)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Budget").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
            }
            .onAppear { amountText = String(status.limit) }
            .alert("Remove Budget", isPresented: $showDeleteAlert) {
                Button("Remove", role: .destructive) {
                    BudgetManager.shared.deleteBudget(id: status.budget.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove the \(status.label) budget limit?")
            }
        }
    }

    func handleKey(_ key: String) {
        switch key {
        case "⌫": amountText = amountText.count > 1 ? String(amountText.dropLast()) : "0"
        case ".":  if !amountText.contains(".") { amountText += "." }
        default:   amountText = amountText == "0" ? key : amountText.count < 9 ? amountText + key : amountText
        }
    }
}
