// Views/Transaction/CategoryPickerView.swift
import SwiftUI

struct CategoryPickerView: View {

    let type:             String
    @Binding var selected: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: ThemeManager

    @State private var searchText    = ""
    @State private var showAddSheet  = false

    private let coreData = CoreDataManager.shared

    var allCategories: [CategoryEntity] {
        // ✅ Deduplicate by name — keep newest
        let all  = coreData.fetchCategories(type: type)
        var seen = Set<String>()
        var unique: [CategoryEntity] = []
        for cat in all {
            let name = cat.name ?? ""
            if !seen.contains(name) {
                seen.insert(name)
                unique.append(cat)
            }
        }
        return unique
    }

    var filtered: [CategoryEntity] {
        if searchText.isEmpty { return allCategories }
        return allCategories.filter {
            ($0.name ?? "").lowercased()
                .contains(searchText.lowercased())
        }
    }

    // Group by section
    var sections: [(String, [CategoryEntity])] {
        if type == "income" {
            return [("All Income", filtered)]
        }
        let groups: [(String, [String])] = [
            ("🍽 Food & Drink",   ["Groceries","Restaurant","Coffee","Alcohol"]),
            ("🏠 Home",           ["Rent","Utilities","Internet","Furniture","Repairs"]),
            ("🚗 Transport",      ["Fuel","Taxi/Uber","Flight","Train","Parking"]),
            ("💊 Health",         ["Medicine","Doctor","Gym","Salon"]),
            ("🛍 Shopping",       ["Clothes","Electronics","Games","Movies","Books","Music","Sport"]),
            ("🌍 Life",           ["Education","Kids","Pet","Travel","Hotel","Insurance","Tax","Charity","Subscriptions","Other"]),
        ]
        var result: [(String, [CategoryEntity])] = []
        var usedNames = Set<String>()
        for (title, names) in groups {
            let cats = filtered.filter {
                names.contains($0.name ?? "") &&
                !usedNames.contains($0.name ?? "")
            }
            if !cats.isEmpty {
                cats.forEach { usedNames.insert($0.name ?? "") }
                result.append((title, cats))
            }
        }
        // Custom categories not in any group
        let custom = filtered.filter {
            !usedNames.contains($0.name ?? "")
        }
        if !custom.isEmpty {
            result.append(("⚡️ Custom", custom))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.0) { title, cats in
                    Section(title) {
                        ForEach(cats, id: \.id) { cat in
                            Button {
                                selected = cat.name ?? ""
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text(cat.icon ?? "📌")
                                        .font(.title2)
                                        .frame(width: 36)

                                    Text(cat.name ?? "")
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if selected == cat.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.accent)
                                    }
                                }
                            }
                        }
                        .onDelete { idx in
                            // Don't delete built-in categories
                            let toDelete = idx.map { cats[$0] }
                            toDelete.forEach {
                                if !isBuiltIn($0.name ?? "") {
                                    coreData.deleteCategory($0)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt: "Search categories"
            )
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddCategoryView(type: type)
                    .environmentObject(theme)
            }
        }
    }

    func isBuiltIn(_ name: String) -> Bool {
        let builtIn = [
            "Salary","Freelance","Business","Investment","Rental",
            "Gift","Bonus","Refund","Side Hustle","Groceries",
            "Restaurant","Coffee","Alcohol","Rent","Utilities",
            "Internet","Furniture","Repairs","Fuel","Taxi/Uber",
            "Flight","Train","Parking","Medicine","Doctor","Gym",
            "Salon","Clothes","Electronics","Games","Movies","Books",
            "Music","Sport","Education","Kids","Pet","Travel","Hotel",
            "Insurance","Tax","Charity","Subscriptions","Other"
        ]
        return builtIn.contains(name)
    }
}
