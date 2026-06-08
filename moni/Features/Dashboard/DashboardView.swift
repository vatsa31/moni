//
//  DashboardView.swift
//  moni
//

import SwiftUI

extension ContentView {
    var dashboard: some View {
        let monthStart = Calendar.current.startOfMonth(for: .now)
        let totalBudget = totalBudget(for: monthStart)
        let monthlySpent = FinanceCalculator.monthlyExpenses(in: transactions, month: monthStart)
        let budgetState = FinanceCalculator.budgetState(
            spentPaise: monthlySpent,
            budgetPaise: totalBudget?.totalBudgetPaise ?? 0
        )
        let budgetProgress = FinanceCalculator.progress(
            spentPaise: monthlySpent,
            budgetPaise: totalBudget?.totalBudgetPaise ?? 0
        )

        return ZStack {
            AppBackdrop()

            ScrollView {
                VStack(spacing: 18) {
                    topControlStrip(title: "Today", subtitle: "Manual money flow")

                    BudgetHeroCard(
                        monthlySpentPaise: monthlySpent,
                        totalBudgetPaise: totalBudget?.totalBudgetPaise,
                        budgetProgress: budgetProgress,
                        budgetState: budgetState,
                        isVisible: dashboardAppeared
                    ) {
                        withAnimation(Motion.snappy) {
                            activeSheet = .budget
                        }
                    }
                    .onAppear {
                        withAnimation(Motion.entrance.delay(0.04)) {
                            dashboardAppeared = true
                        }
                    }
                    .onDisappear {
                        dashboardAppeared = false
                    }

                    SectionPanel(title: "Accounts", iconName: "wallet.pass") {
                        VStack(spacing: 10) {
                            ForEach(Array(activeAccounts.enumerated()), id: \.offset) { index, account in
                                Button {
                                    withAnimation(Motion.snappy) {
                                        activeSheet = .account(account)
                                    }
                                } label: {
                                    AccountRowView(
                                        account: account,
                                        balancePaise: FinanceCalculator.balance(for: account, transactions: transactions)
                                    )
                                    .motionRow(index: index, isVisible: dashboardAppeared)
                                }
                                .buttonStyle(MicroPressButtonStyle())
                            }

                            Button {
                                withAnimation(Motion.snappy) {
                                    activeSheet = .account(nil)
                                }
                            } label: {
                                Label("Add account", systemImage: "plus.circle")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.moniLeaf)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                            .buttonStyle(MicroPressButtonStyle())
                        }
                    }

                    SectionPanel(title: "Today’s transactions", iconName: "sparkles") {
                        let todaysTransactions = transactions.filter { Calendar.current.isDateInToday($0.date) }

                        if todaysTransactions.isEmpty {
                            EmptyStatePanel(
                                title: "No movement today",
                                subtitle: "Tap the center plus to create today’s first expense.",
                                iconName: "tray"
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(todaysTransactions.enumerated()), id: \.offset) { index, transaction in
                                    Button {
                                        withAnimation(Motion.snappy) {
                                            activeSheet = .transaction(type: transaction.type, transaction: transaction)
                                        }
                                    } label: {
                                        TransactionRowView(transaction: transaction)
                                            .motionRow(index: index + 2, isVisible: dashboardAppeared)
                                    }
                                    .buttonStyle(MicroPressButtonStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation(Motion.snappy) {
                                                modelContext.delete(transaction)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionPanel(title: "Budget signals", iconName: "chart.bar.xaxis") {
                        let categoryBudgets = budgetsForMonth(monthStart).filter { $0.category != nil }

                        if categoryBudgets.isEmpty {
                            Text("No category budgets set.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.moniMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(categoryBudgets.enumerated()), id: \.offset) { index, budget in
                                    if let category = budget.category {
                                        CategoryBudgetRowView(
                                            category: category,
                                            budgetPaise: budget.totalBudgetPaise,
                                            spentPaise: FinanceCalculator.monthlyExpenses(
                                                in: transactions,
                                                category: category,
                                                month: monthStart
                                            )
                                        )
                                        .motionRow(index: index + 4, isVisible: dashboardAppeared)
                                    }
                                }
                            }
                        }

                        Button {
                            withAnimation(Motion.snappy) {
                                activeSheet = .categories
                            }
                        } label: {
                            Label("Manage categories", systemImage: "tag")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.moniLeaf)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                        .buttonStyle(MicroPressButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 118)
            }
            .scrollIndicators(.hidden)
        }
    }

    func topControlStrip(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.moniInk)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()

            themeMenu
                .labelStyle(.iconOnly)
                .controlSize(.large)
                .tint(Color.moniInk)

            Button {
                withAnimation(Motion.snappy) {
                    activeSheet = .budget
                }
            } label: {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.moniInk)
                    .frame(width: 42, height: 42)
                    .background(Color.moniSurface, in: Circle())
                    .shadow(color: Color.moniInk.opacity(0.08), radius: 12, y: 6)
            }
            .buttonStyle(MicroPressButtonStyle())
            .accessibilityLabel("Budget")
        }
    }

    func totalBudget(for monthStart: Date) -> MonthlyBudget? {
        budgets.first {
            Calendar.current.isDate($0.monthStart, inSameMonthAs: monthStart) && $0.category == nil
        }
    }

    func budgetsForMonth(_ monthStart: Date) -> [MonthlyBudget] {
        budgets.filter { Calendar.current.isDate($0.monthStart, inSameMonthAs: monthStart) }
    }
}
