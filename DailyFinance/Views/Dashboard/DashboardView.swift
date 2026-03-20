//
//  DashboardView.swift
//  DailyFinance
//
//  Created by Shibbir on 19/3/26.
//


// Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {

    // MARK: - Properties
    @StateObject private var controller = TransactionController.shared
    @StateObject private var auth       = AuthController.shared
    @StateObject private var sync       = SyncService.shared
    // ✅ Live currency updates
    @EnvironmentObject private var preferences: UserPreferences

    @State private var showAddTransaction = false
    @State private var showHistory        = false
    @State private var transactionType    = "expense"
    @State private var showProfile        = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        balanceCard
                        summaryCards
                        quickAddButtons
                        todayTransactionsList
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal)
                }

                floatingAddButton
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(defaultType: transactionType)
                    .environmentObject(preferences)
                    // ✅ id() forces fresh view on every open
                    // Fixes "always shows expense first time"
                    .id(transactionType)
                    .onDisappear {
                        controller.loadTodayData()
                    }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(preferences)  // ✅ pass down
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
                    .environmentObject(preferences)  // ✅ pass down
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

            HStack(spacing: 12) {
                // Sync indicator
                Image(systemName: sync.isSyncing
                    ? "arrow.triangle.2.circlepath"
                    : "checkmark.icloud")
                    .foregroundColor(sync.isSyncing ? .orange : .green)
                    .font(.title3)

                // History button
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.primary)
                }

                // Profile button
                Button {
                    showProfile = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
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

            // ✅ Uses preferences.format() — updates live!
            Text(preferences.format(controller.todayBalanceAmount))
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

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
            LinearGradient(
                colors: (controller.todayBalanceAmount >= 0)
                    ? [.green, .teal]
                    : [.red, .orange],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(
            color: (controller.todayBalanceAmount >= 0)
                ? .green.opacity(0.3)
                : .red.opacity(0.3),
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
                color:  .green
            )
            .environmentObject(preferences)  // ✅

            SummaryCardView(
                title:  "Expenses",
                amount: controller.todayExpenseAmount,
                icon:   "arrow.up.circle.fill",
                color:  .red
            )
            .environmentObject(preferences)  // ✅
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
                .background(Color.green)
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

    // MARK: - Today's Transactions List
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
                        id: \.id
                    ) { transaction in
                        TransactionRowView(transaction: transaction)
                            .environmentObject(preferences)  // ✅
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
                .background(Color.green)
                .clipShape(Circle())
                .shadow(color: .green.opacity(0.4), radius: 10)
        }
        .padding(.bottom, 20)
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

    // ✅ Now uses UserPreferences — updates live!
    func formatCurrency(_ value: Double) -> String {
        return preferences.format(value)
    }
}