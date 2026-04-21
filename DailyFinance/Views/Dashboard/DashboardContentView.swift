// Views/Dashboard/DashboardContentView.swift
import SwiftUI
internal import CoreData

struct DashboardContentView: View {

    @StateObject private var controller    = TransactionController.shared
    @StateObject private var auth          = AuthController.shared
    @StateObject private var sync          = SyncService.shared
    @StateObject private var budgetManager = BudgetManager.shared
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    @State private var showAddTransaction  = false
    @State private var transactionType     = "expense"
    @State private var editingTransaction: TransactionEntity? = nil
    @State private var refreshID:          UUID = UUID()
    @State private var showWidgetPrompt:   Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                    theme.lightBg.ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 12) {

                        // 1. Header
                        headerSection

                        // 2. iCloud restore banner (fresh install only)
                        if auth.isSyncingFromICloud {
                            ICloudSyncBanner()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 3. iCloud error (storage full etc.)
                        iCloudErrorBanner

                        // 4. Monthly chart
                        MonthlyExpenseChartCard
                            .buildFromCoreData()
                            .environmentObject(preferences)

                        // 5. Balance hero card (income/expense inside)
                        balanceCard.id(refreshID)

                        // 6. Add buttons
                        quickAddButtons

                        // 7. Budget summary — collapsible
                        BudgetSummaryCard()
                            .environmentObject(preferences)
                            .environmentObject(theme)

                        // 9. Today's transactions
                        todayTransactionsList

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.4),
                               value: auth.isSyncingFromICloud)
                }
            }
            .navigationBarHidden(true)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
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
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("iCloudDataChanged")
            )) { _ in
                controller.loadTodayData()
                controller.loadCategories()
                budgetManager.recalculateStatuses()
                refreshID = UUID()  // ✅ force balance card re-render
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("TransactionEdited")
            )) { _ in
                controller.loadTodayData()
                budgetManager.recalculateStatuses()
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("SessionRestored")
            )) { _ in
                budgetManager.loadBudgets()
                for delay in [5.0, 10.0, 20.0, 30.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let count = CoreDataManager.shared
                            .fetchTransactions(for: Date()).count
                        if count > 0 { controller.loadTodayData() }
                    }
                }
            }
            // ✅ Show widget prompt once on first ever app open
            .onAppear {
               
                if !UserDefaults.standard.bool(forKey: "widgetPromptShown") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showWidgetPrompt = true
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(defaultType: transactionType)
                    .environmentObject(preferences)
                    .environmentObject(theme)
                    .id(transactionType)
                    .onDisappear {
                        controller.loadTodayData()
                        budgetManager.checkAfterTransaction(
                            category: "",
                            type: transactionType
                        )
                    }
            }
            .sheet(item: $editingTransaction) { tx in
                EditTransactionView(transaction: tx)
                    .environmentObject(preferences)
                    .environmentObject(theme)
                    .onDisappear {
                        DispatchQueue.main.async {
                            controller.loadTodayData()
                            budgetManager.recalculateStatuses()
                            refreshID = UUID()
                        }
                    }
            }
            // ✅ Widget onboarding prompt — shows once after first login
            .sheet(isPresented: $showWidgetPrompt) {
                WidgetPromptView()
                    .environmentObject(theme)
            }
        }
    }

    // MARK: - Header
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText())
                    .font(.subheadline).foregroundColor(.secondary)
                Text("My Finance")
                    .font(.title2).fontWeight(.bold)
            }
            Spacer()
            Image(systemName: sync.isSyncing
                  ? "arrow.triangle.2.circlepath"
                  : "checkmark.icloud.fill")
                .foregroundColor(sync.isSyncing ? .orange : theme.accent)
                .font(.title3)
                .symbolEffect(.rotate, isActive: sync.isSyncing)
        }
        .padding(.top, 10)
    }

    // MARK: - Balance Card (with income/expense inside)
    var balanceCard: some View {
        VStack(spacing: 0) {

            // ── Top: net balance ───────────────────────
            VStack(spacing: 4) {
                Text(todayDateString())
                    .font(.caption2).foregroundColor(.white.opacity(0.8))
                Text("Today's Balance")
                    .font(.caption).foregroundColor(.white.opacity(0.9))
                Text(preferences.format(controller.todayBalanceAmount))
                    .font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Image(systemName: controller.todayBalanceAmount >= 0
                          ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption2)
                    Text(controller.todayBalanceAmount >= 0 ? "Profit" : "Loss")
                        .font(.caption2).fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.white.opacity(0.2)).cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16).padding(.bottom, 12)

            // ── Divider ────────────────────────────────
            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            // ── Bottom: income / expense ───────────────
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill").font(.caption2)
                        Text("Income").font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    Text(preferences.format(controller.todayIncomeAmount))
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 0.5, height: 32)

                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill").font(.caption2)
                        Text("Expense").font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    Text(preferences.format(controller.todayExpenseAmount))
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
        }
        .background(Group {
            if controller.todayBalanceAmount >= 0 { theme.gradient }
            else {
                LinearGradient(
                    colors: [.red, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        })
        .cornerRadius(20)
        .shadow(
            color: controller.todayBalanceAmount >= 0
                ? theme.accent.opacity(0.3) : .red.opacity(0.3),
            radius: 10
        )
    }

    // MARK: - Quick Add Buttons
    var quickAddButtons: some View {
        HStack(spacing: 12) {
            Button {
                transactionType = "income"
                showAddTransaction = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.subheadline)
                    Text("Add Income").fontWeight(.semibold).font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.accent).foregroundColor(.white).cornerRadius(12)
            }
            Button {
                transactionType = "expense"
                showAddTransaction = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle.fill").font(.subheadline)
                    Text("Add Expense").fontWeight(.semibold).font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red).foregroundColor(.white).cornerRadius(12)
            }
        }
    }

    // MARK: - Today's Transactions
    var todayTransactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Transactions")
                    .font(.headline).fontWeight(.bold)
                Spacer()
                Text("\(controller.todayTransactions.count) items")
                    .font(.caption).foregroundColor(.secondary)
            }

            if controller.todayTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40)).foregroundColor(.secondary)
                    Text("No transactions today").foregroundColor(.secondary)
                    Text("Tap + to add your first one!")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(controller.todayTransactions, id: \.objectID) { tx in
                        TransactionRowView(transaction: tx)
                            .id("\(tx.objectID)-\(tx.amount)-\(tx.category ?? "")")
                            .environmentObject(preferences)
                            .padding(.vertical, 8).padding(.horizontal)
                            .background(Color(.systemBackground))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    controller.deleteTransaction(tx)
                                    budgetManager.recalculateStatuses()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button { editingTransaction = tx } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(theme.accent)
                            }
                            .onTapGesture { editingTransaction = tx }

                        if tx != controller.todayTransactions.last {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8)
            }
        }
    }

    // MARK: - iCloud Error Banner
    @ViewBuilder
    var iCloudErrorBanner: some View {
        if let error = CoreDataManager.shared.iCloudError {
            HStack(spacing: 10) {
                Image(systemName: error.icon).foregroundColor(.white)
                Text(error.message).font(.caption).foregroundColor(.white).lineLimit(2)
                Spacer()
                if case .storageFull = error {
                    Button("Fix") {
                        if let url = URL(string: "App-Prefs:root=CASTLE") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption).fontWeight(.bold).foregroundColor(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white).cornerRadius(10)
                }
            }
            .padding()
            .background(error.icon == "icloud.slash.fill" ? Color.orange : Color.red)
            .cornerRadius(12)
            .transition(.move(edge: .top).combined(with: .opacity))
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
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d yyyy"
        return f.string(from: Date())
    }
}
