
//
//  FinanceEntry.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// DailyFinanceWidget/DailyFinanceWidget.swift
// ✅ Add this file to the Widget Extension target (not the main app target)

import WidgetKit
import SwiftUI
import CoreData

// MARK: - Widget Entry
struct FinanceEntry: TimelineEntry {
    let date:    Date
    let balance: Double
    let income:  Double
    let expense: Double
    let isProfit: Bool
    let dateString: String
    let currency: String
}

// MARK: - Timeline Provider
struct FinanceProvider: TimelineProvider {

    // Placeholder shown in widget gallery
    func placeholder(in context: Context) -> FinanceEntry {
        FinanceEntry(
            date:       Date(),
            balance:    1250.00,
            income:     1500.00,
            expense:    250.00,
            isProfit:   true,
            dateString: "Today",
            currency:   "USD"
        )
    }

    // Snapshot shown during widget picker preview
    func getSnapshot(
        in context: Context,
        completion: @escaping (FinanceEntry) -> Void
    ) {
        completion(loadEntry())
    }

    // Actual timeline — refresh every 30 minutes
    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FinanceEntry>) -> Void
    ) {
        let entry      = loadEntry()
        let nextUpdate = Calendar.current.date(
            byAdding: .minute, value: 30, to: Date()
        ) ?? Date()
        let timeline   = Timeline(
            entries:     [entry],
            policy:      .after(nextUpdate)
        )
        completion(timeline)
    }

    // MARK: - Load Data from Shared Core Data
    private func loadEntry() -> FinanceEntry {
        let store     = SharedDataStore.shared
        let today     = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr   = formatter.string(from: today)

        let income    = store.fetchTodayIncome(for: dateStr)
        let expense   = store.fetchTodayExpense(for: dateStr)
        let balance   = income - expense
        let currency  = UserDefaults(
            suiteName: SharedDataStore.appGroupID
        )?.string(forKey: "userCurrency") ?? "USD"

        let dayFormatter        = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"

        return FinanceEntry(
            date:       today,
            balance:    balance,
            income:     income,
            expense:    expense,
            isProfit:   balance >= 0,
            dateString: dayFormatter.string(from: today),
            currency:   currency
        )
    }
}

// MARK: - Shared Data Store
// ✅ Reads from the App Group shared Core Data container
struct SharedDataStore {

    static let shared     = SharedDataStore()
    // ✅ Must match exactly what you set in Xcode
    // App Group identifier format: group.com.yourname.DailyFinance
    static let appGroupID = "group.shibbir.DailyFinance"

    private let context: NSManagedObjectContext?

    init() {
        guard let groupURL = FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: SharedDataStore.appGroupID
            )
        else {
            print("❌ Widget: App Group not found")
            context = nil
            return
        }

        let storeURL   = groupURL.appendingPathComponent("DailyFinance.sqlite")
        let container  = NSPersistentContainer(name: "DailyFinance")
        let desc       = NSPersistentStoreDescription(url: storeURL)
        desc.setOption(true as NSNumber,
                       forKey: NSMigratePersistentStoresAutomaticallyOption)
        desc.setOption(true as NSNumber,
                       forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            print("❌ Widget store error: \(error)")
            context = nil
        } else {
            context = container.viewContext
        }
    }

    func fetchTodayIncome(for dateStr: String) -> Double {
        guard let ctx = context else { return 0 }
        let req = NSFetchRequest<NSManagedObject>(entityName: "DailySummaryEntity")
        req.predicate  = NSPredicate(format: "date == %@", dateStr)
        req.fetchLimit = 1
        let result = try? ctx.fetch(req)
        return result?.first?.value(forKey: "totalIncome") as? Double ?? 0
    }

    func fetchTodayExpense(for dateStr: String) -> Double {
        guard let ctx = context else { return 0 }
        let req = NSFetchRequest<NSManagedObject>(entityName: "DailySummaryEntity")
        req.predicate  = NSPredicate(format: "date == %@", dateStr)
        req.fetchLimit = 1
        let result = try? ctx.fetch(req)
        return result?.first?.value(forKey: "totalExpense") as? Double ?? 0
    }
}

// MARK: - Widget View
struct DailyFinanceWidgetView: View {

    var entry: FinanceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        mediumWidget
    }

    // MARK: - Medium Widget
    var mediumWidget: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: entry.isProfit
                    ? [Color(red: 0.13, green: 0.77, blue: 0.37),
                       Color(red: 0.05, green: 0.58, blue: 0.53)]
                    : [Color(red: 0.85, green: 0.15, blue: 0.15),
                       Color(red: 0.95, green: 0.45, blue: 0.10)],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )

            HStack(spacing: 0) {

                // ── Left: Balance ──────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("DailyFinance")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Text("Today's Balance")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))

                    Text(formatAmount(entry.balance))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: entry.isProfit
                              ? "arrow.up.circle.fill"
                              : "arrow.down.circle.fill")
                            .font(.caption2)
                        Text(entry.isProfit ? "Profit" : "Loss")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2))
                    .cornerRadius(20)

                    Spacer()

                    Text(entry.dateString)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.leading, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── Divider ────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 0.5)
                    .padding(.vertical, 16)

                // ── Right: Income + Expense ────────────
                VStack(spacing: 0) {

                    // Income
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                            Text("Income")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Text(formatAmount(entry.income))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 14)

                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)

                    // Expense
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                            Text("Expense")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Text(formatAmount(entry.expense))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 14)
                }
                .frame(width: 130)
            }
        }
        // ✅ Deep link — tapping widget opens the app
        .widgetURL(URL(string: "dailyfinance://dashboard"))
    }

    // MARK: - Format Amount
    func formatAmount(_ value: Double) -> String {
        let symbol: String
        switch entry.currency {
        case "GBP": symbol = "£"
        case "EUR": symbol = "€"
        case "CAD": symbol = "C$"
        case "AUD": symbol = "A$"
        default:    symbol = "$"
        }
        let abs = Swift.abs(value)
        if abs >= 10000 {
            return String(format: "\(symbol)%.1fk", abs / 1000)
        }
        let formatter            = NumberFormatter()
        formatter.numberStyle    = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: abs)) ?? "0.00"
        return value < 0 ? "-\(symbol)\(formatted)" : "\(symbol)\(formatted)"
    }
}

// MARK: - Widget Configuration
@main
struct DailyFinanceWidget: Widget {
    let kind = "DailyFinanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind:     kind,
            provider: FinanceProvider()
        ) { entry in
            DailyFinanceWidgetView(entry: entry)
        }
        .configurationDisplayName("DailyFinance")
        .description("Today's balance, income and expenses.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview
struct DailyFinanceWidget_Previews: PreviewProvider {
    static var previews: some View {
        DailyFinanceWidgetView(entry: FinanceEntry(
            date:       Date(),
            balance:    484.10,
            income:     1054.10,
            expense:    570.00,
            isProfit:   true,
            dateString: "Saturday, Mar 21",
            currency:   "USD"
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
