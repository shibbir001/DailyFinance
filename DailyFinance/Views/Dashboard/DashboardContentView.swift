// Views/Dashboard/DashboardContentView.swift
// ✅ Renamed from DashboardView
// DashboardView now just hosts the tab bar
import SwiftUI
internal import CoreData

struct DashboardContentView: View {

    // MARK: - Properties
    @StateObject private var controller = TransactionController.shared
    @StateObject private var auth       = AuthController.shared
    @StateObject private var sync       = SyncService.shared
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    @State private var showAddTransaction   = false
    @State private var transactionType      = "expense"
    @State private var editingTransaction:  TransactionEntity? = nil
    @State private var refreshID:           UUID = UUID()

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    // ✅ Subtle theme tint on background
                    theme.lightBg
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        // ✅ Show iCloud error if any
                        iCloudErrorBanner
                        // ✅ Monthly expense chart first
                        MonthlyExpenseChartCard
                            .buildFromCoreData()
                            .environmentObject(preferences)
                        balanceCard
                    .id(refreshID)
                        summaryCards
                        quickAddButtons
                        todayTransactionsList
                        // ✅ Extra padding for tab bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal)
                }

                floatingAddButton
            }
            .navigationBarHidden(true)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            print("🔄 Manual iCloud sync triggered")
                            await SyncService.shared.restoreAllData()
                            TransactionController.shared.loadTodayData()
                            NotificationCenter.default.post(
                                name: NSNotification.Name("iCloudDataChanged"),
                                object: nil
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise.icloud")
                            .foregroundColor(theme.accent)
                    }
                }
            }
            #endif
            // ✅ Refresh when iCloud pushes changes
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("iCloudDataChanged")
                )
            ) { _ in
                print("☁️ Dashboard refreshing from iCloud")
                controller.loadTodayData()
                controller.loadCategories()
            }
            // ✅ Force re-render after edit/delete
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("TransactionEdited")
                )
            ) { _ in
                controller.loadTodayData()
                // ✅ Force SwiftUI to re-render entire view
                refreshID = UUID()
            }
            // ✅ Keep checking for 30s after login
            // iCloud delivers transactions in batches
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("SessionRestored")
                )
            ) { _ in
                // Poll every 5s for 30s after login
                for delay in [5.0, 10.0, 20.0, 30.0] {
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + delay
                    ) {
                        let count = CoreDataManager.shared
                            .fetchTransactions(for: Date()).count
                        if count > 0 {
                            print("📱 iCloud txs arrived after \(Int(delay))s: \(count)")
                            controller.loadTodayData()
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(defaultType: transactionType)
                    .environmentObject(preferences)
                    .environmentObject(theme)
                    .id(transactionType)
                    .onDisappear { controller.loadTodayData() }
            }
            .sheet(item: $editingTransaction) { tx in
                EditTransactionView(transaction: tx)
                    .environmentObject(preferences)
                    .environmentObject(theme)
                    .onDisappear {
                        // ✅ Force UI refresh after edit
                        DispatchQueue.main.async {
                            controller.loadTodayData()
                            refreshID = UUID()
                        }
                    }
            }
        }
    }

    // MARK: - Header Section
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("My Finance")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()

            // Sync indicator
            Image(systemName: sync.isSyncing
                ? "arrow.triangle.2.circlepath"
                : "checkmark.icloud.fill")
                .foregroundColor(sync.isSyncing ? .orange : theme.accent)
                .font(.title3)
                .symbolEffect(.rotate, isActive: sync.isSyncing)
        }
        .padding(.top, 10)
    }

    // MARK: - Balance Card
    var balanceCard: some View {
        VStack(spacing: 8) {
            Text(todayDateString())
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Text("Today's Balance")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            Text(preferences.format(controller.todayBalanceAmount))
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            HStack {
                Image(systemName: (controller.todayBalanceAmount >= 0)
                    ? "arrow.up.circle.fill"
                    : "arrow.down.circle.fill")
                Text((controller.todayBalanceAmount >= 0) ? "Profit" : "Loss")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            Group {
                if (controller.todayBalanceAmount >= 0) {
                    // ✅ Use theme gradient
                    theme.gradient
                } else {
                    LinearGradient(
                        colors: [Color.red, Color.orange],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                }
            }
        )
        .cornerRadius(24)
        .shadow(
            color: (controller.todayBalanceAmount >= 0)
                ? theme.accent.opacity(0.3)
                : Color.red.opacity(0.3),
            radius: 12
        )
    }

    // MARK: - Summary Cards
    var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCardView(
                title:  "Income",
                amount: controller.todayIncomeAmount,
                icon:   "arrow.down.circle.fill",
                color:  theme.accent
            )
            .environmentObject(preferences)

            SummaryCardView(
                title:  "Expenses",
                amount: controller.todayExpenseAmount,
                icon:   "arrow.up.circle.fill",
                color:  .red
            )
            .environmentObject(preferences)
        }
    }

    // MARK: - Quick Add Buttons
    var quickAddButtons: some View {
        HStack(spacing: 12) {
            Button {
                transactionType    = "income"
                showAddTransaction = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Income").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.accent)
                .foregroundColor(.white)
                .cornerRadius(14)
            }

            Button {
                transactionType    = "expense"
                showAddTransaction = true
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

    // MARK: - Today's Transactions
    var todayTransactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Transactions")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(controller.todayTransactions.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if controller.todayTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No transactions today")
                        .foregroundColor(.secondary)
                    Text("Tap + to add your first one!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(
                        controller.todayTransactions,
                        // ✅ Include amount+category in id
                        // Forces re-render when transaction is edited
                        id: \.objectID
                    ) { transaction in
                        TransactionRowView(transaction: transaction)
                            .id("\(transaction.objectID)-\(transaction.amount)-\(transaction.category ?? "")")
                            .environmentObject(preferences)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(Color(.systemBackground))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    controller.deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(theme.accent)
                            }
                            .onTapGesture {
                                editingTransaction = transaction
                            }
                        if transaction != controller.todayTransactions.last {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8)
            }
        }
    }

    // MARK: - Floating Add Button
    var floatingAddButton: some View {
        Button {
            transactionType    = "expense"
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(theme.accent)
                .clipShape(Circle())
                .shadow(color: theme.accent.opacity(0.4), radius: 10)
        }
        .padding(.bottom, 90) // ✅ above tab bar
    }

    // MARK: - iCloud Error Banner
    @ViewBuilder
    var iCloudErrorBanner: some View {
        if let error = CoreDataManager.shared.iCloudError {
            HStack(spacing: 10) {
                Image(systemName: error.icon)
                    .foregroundColor(.white)

                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                if case .storageFull = error {
                    Button("Fix") {
                        if let url = URL(
                            string: "App-Prefs:root=CASTLE"
                        ) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(
                error.icon == "icloud.slash.fill"
                    ? Color.orange : Color.red
            )
            .cornerRadius(12)
            .transition(.move(edge: .top)
                .combined(with: .opacity))
        }
    }

    // MARK: - Helpers
    func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good Morning ☀️"
        case 12..<17: return "Good Afternoon 🌤️"
        default:      return "Good Evening 🌙"
        }
    }

    func todayDateString() -> String {
        let f        = DateFormatter()
        f.dateFormat = "EEEE, MMM d yyyy"
        return f.string(from: Date())
    }

    func formatCurrency(_ value: Double) -> String {
        return preferences.format(value)
    }
}
