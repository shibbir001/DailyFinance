// Views/History/CalendarDayView.swift
import SwiftUI
internal import CoreData

struct CalendarDayView: View {

    // MARK: - Properties
    var date: Date
    @Environment(\.dismiss) var dismiss

    @State private var transactions:     [TransactionEntity] = []
    @State private var showAddSheet:     Bool   = false
    @State private var transactionType:  String = "expense"
    @State private var deleteError:      String = ""
    @State private var showDeleteError:  Bool   = false
    // ✅ Forces summary card to re-read after add/delete
    @State private var summaryRefreshID: UUID   = UUID()

    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager
    let coreData = CoreDataManager.shared

    // MARK: - Computed
    var dateTitle: String {
        let f        = DateFormatter()
        f.dateFormat = "EEEE, MMM d yyyy"
        return f.string(from: date)
    }

    // ✅ ALWAYS use DailySummaryEntity for totals
    // summaryRefreshID forces SwiftUI to re-read
    // after add/delete operations
    var dailySummary: DailySummaryEntity? {
        _ = summaryRefreshID  // ✅ triggers re-evaluation
        let formatter        = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr          = formatter.string(from: date)
        return coreData.fetchDailySummary(for: dateStr)
    }

    var totalIncome: Double {
        return dailySummary?.totalIncome ?? 0
    }

    var totalExpense: Double {
        return dailySummary?.totalExpense ?? 0
    }

    var netBalance: Double { totalIncome - totalExpense }
    var isProfit:   Bool   { netBalance >= 0 }

    var isFutureDate: Bool {
        Calendar.current.startOfDay(for: date) >
        Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // MARK: Day Summary Card
                        daySummaryCard

                        // MARK: Add Buttons
                        if !isFutureDate {
                            addButtons
                        }

                        // MARK: Transactions List
                        transactionsList

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadData() }
            // ✅ Refresh when iCloud syncs new transactions
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("iCloudDataChanged")
                )
            ) { _ in loadData() }
            .sheet(isPresented: $showAddSheet) {
                AddTransactionView(
                    defaultType: transactionType,
                    forDate:     date
                )
                .environmentObject(preferences)
                .environmentObject(theme)
                .id(transactionType)
                .onDisappear {
                    loadData()
                    // ✅ Sync after adding past transaction
                    syncAfterChange()
                }
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError)
            }
        }
    }

    // MARK: - Day Summary Card
    var daySummaryCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Net Balance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(formatCurrency(netBalance))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }

            Divider().background(.white.opacity(0.3))

            HStack {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Income")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(formatCurrency(totalIncome))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 36)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("Expense")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(formatCurrency(totalExpense))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: isProfit
                    ? [.green, .teal]
                    : [.red, .orange],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(
            color: isProfit
                ? .green.opacity(0.3)
                : .red.opacity(0.3),
            radius: 12
        )
    }

    // MARK: - Add Buttons
    var addButtons: some View {
        HStack(spacing: 12) {
            Button {
                transactionType = "income"
                showAddSheet    = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Income").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(14)
            }

            Button {
                transactionType = "expense"
                showAddSheet    = true
            } label: {
                HStack {
                    Image(systemName: "minus.circle.fill")
                    Text("Add Expense").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Transactions List
    var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(transactions.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(isFutureDate
                         ? "Future date"
                         : "No transactions this day")
                        .foregroundColor(.secondary)
                    if !isFutureDate {
                        Text("Tap Add Income or Add Expense")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemBackground))
                .cornerRadius(16)

            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(transactions.enumerated()),
                        id: \.offset
                    ) { index, tx in
                        TransactionRowView(transaction: tx)
                            .environmentObject(preferences)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: true
                            ) {
                                Button(role: .destructive) {
                                    deleteTransaction(at: index)
                                } label: {
                                    Label("Delete",
                                          systemImage: "trash")
                                }
                            }

                        if index < transactions.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 6)
            }
        }
    }

    // MARK: - Load Data
    func loadData() {
        let fetched = coreData.fetchTransactions(for: date)
        DispatchQueue.main.async {
            self.transactions     = fetched
            // ✅ Force summary card to re-read from Core Data
            self.summaryRefreshID = UUID()
        }
    }

    // MARK: - Delete Transaction (objectID approach)
    func deleteTransaction(at index: Int) {
        guard index < transactions.count else {
            print("❌ Index out of range: \(index)")
            return
        }

        let context = coreData.context

        // ✅ Capture objectID BEFORE touching array
        // objectID is permanent and never invalidated
        let objectID = transactions[index].objectID

        print("🗑️ Attempting delete: \(objectID)")

        // ✅ Remove from UI array first for instant feedback
        transactions.remove(at: index)

        // ✅ Delete using smart subtract approach
        do {
            let object = try context
                .existingObject(with: objectID)

            guard let tx = object as? TransactionEntity
            else { return }

            // ✅ Smart delete — subtracts from summary
            coreData.deleteTransactionSmart(tx)

            // ✅ Refresh UI and sync after delete
            DispatchQueue.main.async {
                self.loadData()
            }
            self.syncAfterChange()
            print("✅ Deleted and summary updated!")

        } catch {
            print("❌ Core Data delete error: \(error)")
            DispatchQueue.main.async {
                self.deleteError     = error.localizedDescription
                self.showDeleteError = true
                self.loadData()
            }
        }
    }

    // MARK: - Sync After Change
    // ✅ Real-time sync — fires after every add/delete
    func syncAfterChange() {
        guard NetworkMonitor.shared.isConnected else {
            print("📵 Offline — change queued for later sync")
            return
        }
        Task {
            print("📤 CalendarDay: syncing...")
            await SyncService.shared.syncTodayData()
            print("✅ CalendarDay: sync complete")
        }
    }

        // MARK: - Format Currency
    func formatCurrency(_ value: Double) -> String {
        return preferences.format(value)
    }
}
