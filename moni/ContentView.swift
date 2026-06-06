//
//  ContentView.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabSelectionNamespace

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \SpendingCategory.name) private var categories: [SpendingCategory]
    @Query(sort: \MoneyTransaction.date, order: .reverse) private var transactions: [MoneyTransaction]
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]

    @AppStorage("appTheme") private var appThemeRawValue = AppTheme.system.rawValue
    @State private var activeSheet: ActiveSheet?
    @State private var selectedTab: AppTab = .home
    @State private var quickAmountPaise = 1_000
    @State private var quickDragHeight: CGFloat = 0
    @State private var isChoosingQuickAmount = false
    @State private var quickPickerAmountPaise: Int?
    @State private var categoryDragOffset: CGSize = .zero
    @State private var highlightedQuickCategoryID: PersistentIdentifier?
    @State private var lastQuickDragHapticTime: TimeInterval = 0
    @State private var lastCategoryDragHapticTime: TimeInterval = 0
    @State private var dashboardAppeared = false

    private let quickExpenseLadder = [10, 20, 50, 100, 200, 500, 1_000, 1_500, 2_000, 3_000, 4_000, 5_000]
    private let dragHapticInterval: TimeInterval = 0.08

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var body: some View {
        Group {
            if activeAccounts.isEmpty {
                FirstAccountSetupView(categories: categories)
            } else {
                NavigationStack {
                    currentContent
                        .toolbar(.hidden, for: .navigationBar)
                        .safeAreaInset(edge: .bottom) {
                            bottomActionBar
                        }
                }
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
        .blur(radius: backgroundBlurRadius)
        .animation(.easeOut(duration: 0.18), value: isChoosingQuickAmount)
        .overlay {
            quickExpenseOverlay
        }
        .onAppear {
            presentPendingBackTapExpenseIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                presentPendingBackTapExpenseIfNeeded()
            }
        }
        .onChange(of: activeAccounts.count) { _, _ in
            presentPendingBackTapExpenseIfNeeded()
        }
        .onChange(of: quickExpenseCategories.count) { _, _ in
            presentPendingBackTapExpenseIfNeeded()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .transaction(type, transaction):
                TransactionFormView(
                    transaction: transaction,
                    initialType: type,
                    accounts: activeAccounts,
                    categories: categories
                )
            case let .account(account):
                AccountFormView(account: account)
            case .budget:
                BudgetFormView(categories: categories, budgets: budgets)
            case .categories:
                CategoryManagerView(categories: categories)
            }
        }
    }

    private var themeMenu: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    appThemeRawValue = theme.rawValue
                } label: {
                    Label(theme.title, systemImage: theme == appTheme ? "checkmark" : theme.iconName)
                }
            }
        } label: {
            Label("Theme", systemImage: appTheme.iconName)
        }
        .accessibilityLabel("Theme")
    }

    @ViewBuilder
    private var currentContent: some View {
        switch selectedTab {
        case .home:
            dashboard
        case .history:
            history
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            tabBarButton(.home)

            quickExpenseButton

            tabBarButton(.history)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.moniSurface.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: Color.moniInk.opacity(0.10), radius: 24, y: 12)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    private func tabBarButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(Motion.snappy) {
                selectedTab = tab
            }
            triggerSelectionHaptic(strength: .medium)
        } label: {
            ZStack {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.moniLeaf.opacity(0.14))
                        .matchedGeometryEffect(id: "selectedTab", in: tabSelectionNamespace)
                }

                VStack(spacing: 4) {
                    Image(systemName: selectedTab == tab ? tab.filledIconName : tab.iconName)
                        .font(.title3.weight(.medium))
                        .symbolEffect(.bounce, value: selectedTab == tab)

                    Text(tab.label)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(selectedTab == tab ? Color.moniInk : Color.moniMuted)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(MicroPressButtonStyle())
    }

    private var quickExpenseButton: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.medium))
            .foregroundStyle(Color.moniSurface)
            .frame(width: 62, height: 62)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.moniInk, Color.moniLeaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.36), lineWidth: 1)
                    }
            }
            .shadow(color: Color.moniLeaf.opacity(isChoosingQuickAmount ? 0.34 : 0.22), radius: isChoosingQuickAmount ? 24 : 14, y: isChoosingQuickAmount ? 12 : 7)
            .scaleEffect(isChoosingQuickAmount ? 1.12 : 1)
            .rotationEffect(.degrees(isChoosingQuickAmount ? 135 : 0))
            .offset(y: isChoosingQuickAmount ? -6 : 0)
            .accessibilityLabel("Add expense")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let upwardDrag = max(-value.translation.height, 0)
                        guard upwardDrag > 4 else { return }

                        isChoosingQuickAmount = true
                        let dragLimit = quickDragLimit
                        quickDragHeight = min(upwardDrag, dragLimit)
                        let nextAmountPaise = quickAmount(for: quickDragHeight, dragLimit: dragLimit)
                        if nextAmountPaise != quickAmountPaise {
                            triggerSelectionHaptic(strength: .strong)
                        }
                        triggerQuickDragHapticIfNeeded()
                        quickAmountPaise = nextAmountPaise
                    }
                    .onEnded { value in
                        let upwardDrag = max(-value.translation.height, 0)

                        if upwardDrag > 24, !quickExpenseCategories.isEmpty {
                            triggerImpactHaptic(strength: .heavy)
                            quickPickerAmountPaise = quickAmount(for: min(upwardDrag, quickDragLimit), dragLimit: quickDragLimit)
                            categoryDragOffset = .zero
                            highlightedQuickCategoryID = nil
                        } else {
                            activeSheet = .transaction(type: .expense, transaction: nil)
                        }

                        isChoosingQuickAmount = false
                        quickDragHeight = 0
                    }
            )
            .animation(Motion.bouncy, value: isChoosingQuickAmount)
    }

    private var backgroundBlurRadius: CGFloat {
        if quickPickerAmountPaise != nil {
            return 10
        }

        return isChoosingQuickAmount ? min(quickDragHeight / 44, 10) : 0
    }

    @ViewBuilder
    private var quickExpenseOverlay: some View {
        if isChoosingQuickAmount {
            quickAmountScrubberOverlay
        }

        if let amountPaise = quickPickerAmountPaise {
            QuickCategoryPickerOverlay(
                amountPaise: amountPaise,
                categories: quickExpenseCategories,
                highlightedCategoryID: highlightedQuickCategoryID,
                dragOffset: $categoryDragOffset,
                onDragChanged: { dragLocation, categoryCenters in
                    let nextCategoryID = closestCategoryID(
                        to: dragLocation,
                        in: categoryCenters,
                        maximumDistance: 86
                    )
                    if nextCategoryID != highlightedQuickCategoryID {
                        triggerSelectionHaptic(strength: .strong)
                    }
                    triggerCategoryDragHapticIfNeeded()
                    highlightedQuickCategoryID = nextCategoryID
                },
                onDrop: { dragLocation, categoryCenters in
                    if let categoryID = closestCategoryID(to: dragLocation, in: categoryCenters, maximumDistance: 96),
                       let category = categories.first(where: { $0.persistentModelID == categoryID }) {
                        triggerImpactHaptic(strength: .heavy)
                        saveQuickExpense(amountPaise: amountPaise, category: category)
                    }

                    withAnimation(.easeOut(duration: 0.26)) {
                        quickPickerAmountPaise = nil
                        categoryDragOffset = .zero
                        highlightedQuickCategoryID = nil
                    }
                },
                onCancel: {
                    withAnimation(.easeOut(duration: 0.22)) {
                        quickPickerAmountPaise = nil
                        categoryDragOffset = .zero
                        highlightedQuickCategoryID = nil
                    }
                }
            )
        }
    }

    private var quickAmountScrubberOverlay: some View {
        ZStack {
            Color.black.opacity(min(0.08 + quickDragHeight / quickDragLimit * 0.22, 0.30))
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Text(MoneyFormatting.display(quickAmountPaise))
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(Color.moniInk)
                        .contentTransition(.numericText())

                    VStack(spacing: 8) {
                        ForEach(quickExpenseLadder.reversed(), id: \.self) { amount in
                            HStack(spacing: 8) {
                                Capsule()
                                    .fill(amount * 100 <= quickAmountPaise ? Color.moniLeaf : Color.moniMuted.opacity(0.24))
                                    .frame(width: amount == selectedQuickAmountRupees ? 34 : 16, height: 5)

                                if amount == selectedQuickAmountRupees {
                                    Text(MoneyFormatting.display(amount * 100))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.moniMuted)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .shadow(color: Color.moniInk.opacity(0.12), radius: 18, y: 8)
                .padding(.bottom, 84 + quickDragHeight * 0.58)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    private var dashboard: some View {
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

                    SectionPanel(title: "Recent transactions", iconName: "sparkles") {
                        let recentTransactions = transactions.prefix(8)

                        if recentTransactions.isEmpty {
                            EmptyStatePanel(
                                title: "No movement yet",
                                subtitle: "Tap the center plus to create the first expense.",
                                iconName: "tray"
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(recentTransactions.enumerated()), id: \.offset) { index, transaction in
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

    private func topControlStrip(title: String, subtitle: String) -> some View {
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

    private var quickExpenseCategories: [SpendingCategory] {
        Array(categories.prefix(5))
    }

    private var selectedQuickAmountRupees: Int {
        quickAmountPaise / 100
    }

    private var quickDragLimit: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.bounds.height * 0.75
        #else
        620
        #endif
    }

    private var history: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(spacing: 18) {
                    topControlStrip(title: "History", subtitle: "\(transactions.count) transactions")

                    SectionPanel(title: "All transactions", iconName: "clock") {
                        if transactions.isEmpty {
                            EmptyStatePanel(
                                title: "Nothing here yet",
                                subtitle: "Tap the center plus to add an expense.",
                                iconName: "clock"
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(transactions) { transaction in
                                    Button {
                                        withAnimation(Motion.snappy) {
                                            activeSheet = .transaction(type: transaction.type, transaction: transaction)
                                        }
                                    } label: {
                                        TransactionRowView(transaction: transaction)
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
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 118)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func quickAmount(for upwardDrag: CGFloat, dragLimit: CGFloat) -> Int {
        guard !quickExpenseLadder.isEmpty else { return 1_000 }

        let progress = min(max(Double(upwardDrag / max(dragLimit, 1)), 0), 1)
        let easedProgress = pow(progress, 1.35)
        let index = min(
            Int((easedProgress * Double(quickExpenseLadder.count - 1)).rounded()),
            quickExpenseLadder.count - 1
        )

        return quickExpenseLadder[index] * 100
    }

    private func triggerSelectionHaptic(strength: HapticStrength = .medium) {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        UIImpactFeedbackGenerator(style: strength.impactStyle).impactOccurred(intensity: strength.intensity)
        #endif
    }

    private func triggerImpactHaptic(strength: HapticStrength = .medium) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strength.impactStyle).impactOccurred(intensity: strength.intensity)
        #endif
    }

    private func triggerQuickDragHapticIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastQuickDragHapticTime >= dragHapticInterval else { return }

        lastQuickDragHapticTime = now
        triggerImpactHaptic(strength: .medium)
    }

    private func triggerCategoryDragHapticIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastCategoryDragHapticTime >= dragHapticInterval else { return }

        lastCategoryDragHapticTime = now
        triggerImpactHaptic(strength: .medium)
    }

    private func closestCategoryID(
        to point: CGPoint,
        in categoryCenters: [PersistentIdentifier: CGPoint],
        maximumDistance: CGFloat
    ) -> PersistentIdentifier? {
        categoryCenters
            .map { id, center in
                (id: id, distance: hypot(point.x - center.x, point.y - center.y))
            }
            .filter { $0.distance <= maximumDistance }
            .min { $0.distance < $1.distance }?
            .id
    }

    private func saveQuickExpense(amountPaise: Int, category: SpendingCategory) {
        guard let account = activeAccounts.first else { return }

        modelContext.insert(
            MoneyTransaction(
                amountPaise: amountPaise,
                date: .now,
                type: .expense,
                account: account,
                category: category,
                payee: category.name
            )
        )

        selectedTab = .home
    }

    private func presentPendingBackTapExpenseIfNeeded() {
        guard quickPickerAmountPaise == nil, !activeAccounts.isEmpty, !quickExpenseCategories.isEmpty else { return }
        guard let amountPaise = FinanceStore.consumePendingBackTapExpensePaise() else { return }

        selectedTab = .home
        quickAmountPaise = amountPaise
        categoryDragOffset = .zero
        highlightedQuickCategoryID = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            quickPickerAmountPaise = amountPaise
        }
    }

    private func totalBudget(for monthStart: Date) -> MonthlyBudget? {
        budgets.first {
            Calendar.current.isDate($0.monthStart, inSameMonthAs: monthStart) && $0.category == nil
        }
    }

    private func budgetsForMonth(_ monthStart: Date) -> [MonthlyBudget] {
        budgets.filter { Calendar.current.isDate($0.monthStart, inSameMonthAs: monthStart) }
    }

    private func deleteTransactions(offsets: IndexSet) {
        let recentTransactions = Array(transactions.prefix(8))

        withAnimation {
            for index in offsets {
                modelContext.delete(recentTransactions[index])
            }
        }
    }

    private func deleteHistoryTransactions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(transactions[index])
            }
        }
    }

    private func ambientColors(progress: Double, state: BudgetColorState) -> [Color] {
        switch state {
        case .neutral:
            return [
                .gray.opacity(0.12),
                .gray.opacity(0.06)
            ]
        case .green:
            if progress < 0.5 {
                return [
                    .mint.opacity(0.28),
                    .cyan.opacity(0.18),
                    .blue.opacity(0.12)
                ]
            }

            return [
                .teal.opacity(0.24),
                .green.opacity(0.18),
                .yellow.opacity(0.14)
            ]
        case .yellow:
            return [
                .yellow.opacity(0.26),
                .orange.opacity(0.20),
                .pink.opacity(0.12)
            ]
        case .red:
            return [
                .orange.opacity(0.28),
                .pink.opacity(0.22),
                .red.opacity(0.16)
            ]
        }
    }

    private func ambientShadowColor(for state: BudgetColorState) -> Color {
        switch state {
        case .neutral:
            .black.opacity(0.08)
        case .green:
            .teal.opacity(0.16)
        case .yellow:
            .orange.opacity(0.18)
        case .red:
            .red.opacity(0.16)
        }
    }

    private func color(for state: BudgetColorState) -> Color {
        switch state {
        case .neutral:
            .primary
        case .green:
            .green
        case .yellow:
            .orange
        case .red:
            .red
        }
    }
}

private struct AppBackdrop: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let x = CGFloat((sin(t * 0.18) + 1) / 2)
            let y = CGFloat((cos(t * 0.14) + 1) / 2)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.moniCanvas,
                        Color.moniMist,
                        Color(red: 0.94, green: 0.97, blue: 0.91)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color.moniLeaf.opacity(0.24), .clear],
                    center: UnitPoint(x: 0.10 + x * 0.28, y: 0.08 + y * 0.18),
                    startRadius: 10,
                    endRadius: 390
                )

                RadialGradient(
                    colors: [Color.moniSky.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.86 - x * 0.16, y: 0.24 + y * 0.16),
                    startRadius: 18,
                    endRadius: 360
                )

                RadialGradient(
                    colors: [Color.moniLime.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.30 + x * 0.18, y: 0.92),
                    startRadius: 8,
                    endRadius: 320
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct SectionPanel<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.moniLeaf)
                    .frame(width: 30, height: 30)
                    .background(Color.moniLeaf.opacity(0.10), in: Circle())

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)

                Spacer()
            }

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.moniSurface.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
                }
        }
        .shadow(color: Color.moniInk.opacity(0.08), radius: 24, y: 14)
    }
}

private struct EmptyStatePanel: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.moniLeaf)
                .frame(width: 44, height: 44)
                .background(Color.moniLeaf.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.moniMist.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BudgetHeroCard: View {
    let monthlySpentPaise: Int
    let totalBudgetPaise: Int?
    let budgetProgress: Double
    let budgetState: BudgetColorState
    let isVisible: Bool
    let onBudgetTap: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                Spacer(minLength: 44)
                VStack(spacing: 6) {
                    Text("This month")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.moniMuted)
                    Text(MoneyFormatting.display(monthlySpentPaise))
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.moniInk)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                    Text("spent")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.moniMuted)
                }
                .frame(maxWidth: .infinity)

                Button(action: onBudgetTap) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.moniInk)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.62), in: Circle())
                }
                .buttonStyle(MicroPressButtonStyle())
                .accessibilityLabel("Edit budget")
            }

            if let totalBudgetPaise {
                AnimatedProgressBar(progress: budgetProgress, state: budgetState)

                HStack {
                    Text("\(MoneyFormatting.display(max(totalBudgetPaise - monthlySpentPaise, 0))) left")
                    Spacer()
                    Text("Budget \(MoneyFormatting.display(totalBudgetPaise))")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.moniMuted)
                .contentTransition(.numericText())
            } else {
                Text("Set a monthly budget to grade spending.")
                    .font(.footnote)
                    .foregroundStyle(Color.moniMuted)
            }
        }
        .padding(22)
        .background {
            AnimatedBudgetBackdrop(progress: budgetProgress, state: budgetState)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: ambientShadowColor, radius: isVisible ? 32 : 8, y: isVisible ? 16 : 2)
        .scaleEffect(isVisible ? 1 : 0.96)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 16)
    }

    private var ambientShadowColor: Color {
        switch budgetState {
        case .neutral:
            Color.moniInk.opacity(0.12)
        case .green:
            Color.moniLeaf.opacity(0.20)
        case .yellow:
            Color.moniAmber.opacity(0.22)
        case .red:
            Color.moniCoral.opacity(0.22)
        }
    }
}

private struct AnimatedBudgetBackdrop: View {
    let progress: Double
    let state: BudgetColorState

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let drift = CGFloat((sin(t * 0.35) + 1) / 2)

            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: 0.05 + drift * 0.20, y: 0),
                endPoint: UnitPoint(x: 0.90 - drift * 0.12, y: 1)
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18 + min(progress, 1) * 0.08),
                        Color.clear,
                        Color.moniInk.opacity(0.03)
                    ],
                    startPoint: UnitPoint(x: drift, y: 0),
                    endPoint: UnitPoint(x: 1 - drift, y: 1)
                )
                .blendMode(.overlay)
            }
        }
    }

    private var colors: [Color] {
        switch state {
        case .neutral:
            [Color.white, Color.moniMist, Color.moniSky.opacity(0.18)]
        case .green:
            progress < 0.5
                ? [Color.white, Color.moniLime.opacity(0.72), Color.moniSky.opacity(0.18)]
                : [Color.white, Color.moniLeaf.opacity(0.30), Color.moniLime.opacity(0.56)]
        case .yellow:
            [Color.white, Color.moniAmber.opacity(0.42), Color.moniLime.opacity(0.26)]
        case .red:
            [Color.white, Color.moniCoral.opacity(0.26), Color.moniAmber.opacity(0.22)]
        }
    }
}

private struct AnimatedProgressBar: View {
    let progress: Double
    let state: BudgetColorState

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.moniInk.opacity(0.08))

                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * clamped)
                    .animation(Motion.snappy, value: clamped)
            }
        }
        .frame(height: 9)
    }

    private var color: Color {
        switch state {
        case .neutral:
            Color.moniInk.opacity(0.54)
        case .green:
            Color.moniLeaf
        case .yellow:
            Color.moniAmber
        case .red:
            Color.moniCoral
        }
    }
}

private extension View {
    func motionRow(index: Int, isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(Motion.entrance.delay(Double(index) * 0.035), value: isVisible)
    }
}

private struct MicroPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}

private enum Motion {
    static let micro = Animation.spring(response: 0.16, dampingFraction: 0.74)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.34, dampingFraction: 0.68)
    static let entrance = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

private extension Color {
    static let moniCanvas = Color(red: 0.955, green: 0.965, blue: 0.935)
    static let moniSurface = Color(red: 0.995, green: 0.996, blue: 0.980)
    static let moniMist = Color(red: 0.910, green: 0.940, blue: 0.900)
    static let moniInk = Color(red: 0.070, green: 0.095, blue: 0.090)
    static let moniMuted = Color(red: 0.410, green: 0.455, blue: 0.420)
    static let moniLeaf = Color(red: 0.255, green: 0.655, blue: 0.315)
    static let moniLime = Color(red: 0.770, green: 0.925, blue: 0.365)
    static let moniSky = Color(red: 0.650, green: 0.835, blue: 0.920)
    static let moniAmber = Color(red: 0.940, green: 0.645, blue: 0.210)
    static let moniCoral = Color(red: 0.900, green: 0.315, blue: 0.270)
}

private enum AppTab {
    case home
    case history

    var title: String {
        switch self {
        case .home:
            ""
        case .history:
            "History"
        }
    }

    var label: String {
        switch self {
        case .home:
            "Home"
        case .history:
            "History"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            "house"
        case .history:
            "clock"
        }
    }

    var filledIconName: String {
        switch self {
        case .home:
            "house.fill"
        case .history:
            "clock.fill"
        }
    }
}

private enum HapticStrength {
    case medium
    case strong
    case heavy

    #if canImport(UIKit)
    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .medium:
            .medium
        case .strong:
            .rigid
        case .heavy:
            .heavy
        }
    }

    var intensity: CGFloat {
        switch self {
        case .medium:
            0.72
        case .strong:
            0.9
        case .heavy:
            1
        }
    }
    #endif
}

private enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

private enum ActiveSheet: Identifiable {
    case transaction(type: TransactionType, transaction: MoneyTransaction?)
    case account(Account?)
    case budget
    case categories

    var id: String {
        switch self {
        case let .transaction(type, transaction):
            "transaction-\(type.rawValue)-\(transaction?.persistentModelID.hashValue ?? 0)"
        case let .account(account):
            "account-\(account?.persistentModelID.hashValue ?? 0)"
        case .budget:
            "budget"
        case .categories:
            "categories"
        }
    }
}

private struct AccountRowView: View {
    let account: Account
    let balancePaise: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.iconName)
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.moniInk)
                .frame(width: 42, height: 42)
                .background(accountAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(account.type.title)
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()

            Text(MoneyFormatting.display(balancePaise))
                .font(.headline.monospacedDigit())
                .foregroundStyle(balancePaise < 0 ? Color.moniCoral : Color.moniInk)
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private var accountAccent: Color {
        switch account.type {
        case .cash:
            Color.moniLime
        case .bank:
            Color.moniSky
        case .creditCard:
            Color.moniAmber
        }
    }
}

private struct TransactionRowView: View {
    let transaction: MoneyTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.moniInk)
                .frame(width: 42, height: 42)
                .background(amountColor.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(transaction.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()

            Text(amountText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private var primaryText: String {
        if !transaction.payee.isEmpty {
            return transaction.payee
        }

        if transaction.type == .transfer {
            let source = transaction.account?.name ?? "Account"
            let destination = transaction.destinationAccount?.name ?? "Account"
            return "\(source) to \(destination)"
        }

        return transaction.category?.name ?? transaction.type.title
    }

    private var iconName: String {
        switch transaction.type {
        case .expense:
            "minus.circle"
        case .income:
            "plus.circle"
        case .transfer:
            "arrow.left.arrow.right"
        }
    }

    private var amountText: String {
        switch transaction.type {
        case .expense:
            "-\(MoneyFormatting.display(transaction.amountPaise))"
        case .income:
            "+\(MoneyFormatting.display(transaction.amountPaise))"
        case .transfer:
            MoneyFormatting.display(transaction.amountPaise)
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .expense:
            Color.moniCoral
        case .income:
            Color.moniLeaf
        case .transfer:
            Color.moniSky
        }
    }
}

private struct QuickCategoryPickerOverlay: View {
    let amountPaise: Int
    let categories: [SpendingCategory]
    let highlightedCategoryID: PersistentIdentifier?
    @Binding var dragOffset: CGSize
    let onDragChanged: (CGPoint, [PersistentIdentifier: CGPoint]) -> Void
    let onDrop: (CGPoint, [PersistentIdentifier: CGPoint]) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let centers = categoryCenters(in: size)
            let amountPoint = CGPoint(
                x: center.x + dragOffset.width,
                y: center.y + dragOffset.height
            )
            let ringSize = min(size.width * 0.86, size.height * 0.54, 360)
            let sectorCount = max(categories.count, 1)

            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)

                ZStack {
                    ForEach(categories.indices, id: \.self) { index in
                        let category = categories[index]
                        let isHighlighted = highlightedCategoryID == category.persistentModelID
                        let startAngle = Angle.degrees(-90 + Double(index) * 360 / Double(sectorCount))
                        let endAngle = Angle.degrees(-90 + Double(index + 1) * 360 / Double(sectorCount))

                        AnnularSector(startAngle: startAngle, endAngle: endAngle, innerRadiusRatio: 0.44)
                            .fill(sectorFillColor(isHighlighted: isHighlighted))
                            .overlay {
                                AnnularSector(startAngle: startAngle, endAngle: endAngle, innerRadiusRatio: 0.44)
                                    .stroke(Color.moniInk.opacity(0.08), lineWidth: 1)
                            }
                            .animation(.easeOut(duration: 0.14), value: isHighlighted)

                        if let iconPoint = centers[category.persistentModelID] {
                            Image(systemName: categoryIconName(for: category))
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color.moniInk)
                                .frame(width: 46, height: 46)
                                .background(isHighlighted ? Color.moniLime : Color.moniSurface, in: Circle())
                                .scaleEffect(isHighlighted ? 1.12 : 1)
                                .position(
                                    x: iconPoint.x - center.x + ringSize / 2,
                                    y: iconPoint.y - center.y + ringSize / 2
                                )
                        }
                    }

                    Circle()
                        .fill(Color.moniSurface.opacity(0.96))
                        .frame(width: ringSize * 0.44, height: ringSize * 0.44)
                        .overlay {
                            Circle()
                                .stroke(Color.moniInk.opacity(0.08), lineWidth: 1)
                        }
                }
                .frame(width: ringSize, height: ringSize)
                .shadow(color: Color.moniInk.opacity(0.12), radius: 28, y: 14)
                .position(center)

                Text(MoneyFormatting.display(amountPaise))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.moniInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .position(amountPoint)
                    .gesture(
                        DragGesture(coordinateSpace: .named("quickCategoryPicker"))
                            .onChanged { value in
                                dragOffset = value.translation
                                onDragChanged(value.location, centers)
                            }
                            .onEnded { value in
                                onDrop(value.location, centers)
                            }
                    )
            }
            .coordinateSpace(name: "quickCategoryPicker")
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func categoryCenters(in size: CGSize) -> [PersistentIdentifier: CGPoint] {
        guard !categories.isEmpty else { return [:] }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringSize = min(size.width * 0.86, size.height * 0.54, 360)
        let radius = ringSize * 0.35
        let startAngle = -Double.pi / 2
        let angleStep = (Double.pi * 2) / Double(categories.count)

        return Dictionary(
            uniqueKeysWithValues: categories.enumerated().map { index, category in
                let angle = startAngle + angleStep * (Double(index) + 0.5)
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                return (category.persistentModelID, point)
            }
        )
    }

    private func sectorFillColor(isHighlighted: Bool) -> Color {
        isHighlighted ? Color.moniLime.opacity(0.55) : Color.moniSurface.opacity(0.72)
    }

    private func categoryIconName(for category: SpendingCategory) -> String {
        let name = category.name.lowercased()

        if name.contains("food") || name.contains("restaurant") {
            return "fork.knife"
        }
        if name.contains("grocer") {
            return "basket"
        }
        if name.contains("transport") || name.contains("travel") {
            return "car"
        }
        if name.contains("shop") {
            return "bag"
        }
        if name.contains("bill") {
            return "doc.text"
        }
        if name.contains("health") {
            return "cross.case"
        }
        if name.contains("entertain") {
            return "popcorn"
        }

        return "tag"
    }
}

private struct AnnularSector: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio

        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private struct CategoryBudgetRowView: View {
    let category: SpendingCategory
    let budgetPaise: Int
    let spentPaise: Int

    var body: some View {
        let state = FinanceCalculator.budgetState(spentPaise: spentPaise, budgetPaise: budgetPaise)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Spacer()
                Text("\(MoneyFormatting.display(spentPaise)) / \(MoneyFormatting.display(budgetPaise))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.moniMuted)
            }

            AnimatedProgressBar(
                progress: FinanceCalculator.progress(spentPaise: spentPaise, budgetPaise: budgetPaise),
                state: state
            )
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private func tint(for state: BudgetColorState) -> Color {
        switch state {
        case .neutral:
            .secondary
        case .green:
            .green
        case .yellow:
            .orange
        case .red:
            .red
        }
    }
}

private struct PaynoSheetScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let primaryTitle: String?
    let primaryDisabled: Bool
    let onCancel: (() -> Void)?
    let onPrimary: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        primaryTitle: String? = nil,
        primaryDisabled: Bool = false,
        onCancel: (() -> Void)? = nil,
        onPrimary: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.primaryDisabled = primaryDisabled
        self.onCancel = onCancel
        self.onPrimary = onPrimary
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.moniInk)

                            if let subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.moniMuted)
                            }
                        }

                        Spacer()

                        if let onCancel {
                            Button(action: onCancel) {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.moniInk)
                                    .frame(width: 38, height: 38)
                                    .background(Color.moniSurface, in: Circle())
                                    .shadow(color: Color.moniInk.opacity(0.08), radius: 12, y: 6)
                            }
                            .buttonStyle(MicroPressButtonStyle())
                            .accessibilityLabel("Cancel")
                        }
                    }

                    content

                    if let primaryTitle, let onPrimary {
                        Button(primaryTitle, action: onPrimary)
                            .buttonStyle(PaynoPrimaryButtonStyle())
                            .disabled(primaryDisabled)
                            .opacity(primaryDisabled ? 0.45 : 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct PaynoInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.moniMuted)

            TextField(placeholder, text: $text, axis: axis)
                .font(.body)
                .foregroundStyle(Color.moniInk)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.moniMist.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
                }
        }
    }
}

private struct PaynoOptionRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.moniMuted)

            Spacer()

            content
                .font(.body)
                .foregroundStyle(Color.moniInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.moniMist.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct PaynoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.moniSurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.moniInk, Color.moniLeaf],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color.moniLeaf.opacity(configuration.isPressed ? 0.12 : 0.22), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}

private struct PaynoDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.moniCoral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.moniCoral.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}

private struct FirstAccountSetupView: View {
    @Environment(\.modelContext) private var modelContext
    let categories: [SpendingCategory]

    @State private var name = "Main account"
    @State private var type: AccountType = .bank
    @State private var openingBalance = ""
    @State private var monthlyBudget = ""

    var body: some View {
        PaynoSheetScaffold(
            title: "Set up",
            subtitle: "Create the account you want to track first.",
            primaryTitle: "Start tracking",
            primaryDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onPrimary: createAccount
        ) {
            SectionPanel(title: "First account", iconName: "wallet.pass") {
                VStack(spacing: 12) {
                    PaynoInputField(title: "Name", placeholder: "Account name", text: $name)

                    PaynoOptionRow(title: "Type") {
                        Picker("Type", selection: $type) {
                            ForEach(AccountType.allCases) { accountType in
                                Label(accountType.title, systemImage: accountType.iconName)
                                    .tag(accountType)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.moniInk)
                    }

                    PaynoInputField(
                        title: "Opening balance",
                        placeholder: "0",
                        text: $openingBalance,
                        keyboardType: .decimalPad
                    )
                }
            }

            SectionPanel(title: "Monthly budget", iconName: "chart.pie") {
                PaynoInputField(
                    title: "Total budget",
                    placeholder: "0",
                    text: $monthlyBudget,
                    keyboardType: .decimalPad
                )
            }
        }
    }

    private func createAccount() {
        ensureDefaultCategories()

        let account = Account(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            openingBalancePaise: MoneyFormatting.paise(from: openingBalance)
        )
        modelContext.insert(account)

        let budgetPaise = MoneyFormatting.paise(from: monthlyBudget)
        if budgetPaise > 0 {
            modelContext.insert(
                MonthlyBudget(
                    monthStart: Calendar.current.startOfMonth(for: .now),
                    totalBudgetPaise: budgetPaise
                )
            )
        }
    }

    private func ensureDefaultCategories() {
        guard categories.isEmpty else { return }

        for name in ["Food", "Groceries", "Transport", "Shopping", "Bills", "Health", "Entertainment", "Travel"] {
            modelContext.insert(SpendingCategory(name: name, isDefault: true))
        }
    }
}

private struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let account: Account?

    @State private var name: String
    @State private var type: AccountType
    @State private var openingBalance: String
    @State private var isArchived: Bool

    init(account: Account?) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .bank)
        _openingBalance = State(initialValue: MoneyFormatting.rupeesText(fromPaise: account?.openingBalancePaise ?? 0))
        _isArchived = State(initialValue: account?.isArchived ?? false)
    }

    var body: some View {
        PaynoSheetScaffold(
            title: account == nil ? "Add account" : "Edit account",
            subtitle: "Set the account type and opening balance.",
            primaryTitle: "Save",
            primaryDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onCancel: { dismiss() },
            onPrimary: save
        ) {
            SectionPanel(title: "Account", iconName: "wallet.pass") {
                VStack(spacing: 12) {
                    PaynoInputField(title: "Name", placeholder: "Account name", text: $name)

                    PaynoOptionRow(title: "Type") {
                        Picker("Type", selection: $type) {
                            ForEach(AccountType.allCases) { accountType in
                                Label(accountType.title, systemImage: accountType.iconName)
                                    .tag(accountType)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.moniInk)
                    }

                    PaynoInputField(
                        title: "Opening balance",
                        placeholder: "0",
                        text: $openingBalance,
                        keyboardType: .decimalPad
                    )

                    if account != nil {
                        PaynoOptionRow(title: "Archived") {
                            Toggle("Archived", isOn: $isArchived)
                                .labelsHidden()
                                .tint(Color.moniLeaf)
                        }
                    }
                }
            }
        }
    }

    private func save() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let openingBalancePaise = MoneyFormatting.paise(from: openingBalance)

        if let account {
            account.name = cleanedName
            account.type = type
            account.openingBalancePaise = openingBalancePaise
            account.isArchived = isArchived
        } else {
            modelContext.insert(
                Account(
                    name: cleanedName,
                    type: type,
                    openingBalancePaise: openingBalancePaise
                )
            )
        }

        dismiss()
    }
}

private struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let transaction: MoneyTransaction?
    let accounts: [Account]
    let categories: [SpendingCategory]

    @State private var type: TransactionType
    @State private var amount: String
    @State private var date: Date
    @State private var accountID: PersistentIdentifier?
    @State private var destinationAccountID: PersistentIdentifier?
    @State private var categoryID: PersistentIdentifier?
    @State private var payee: String
    @State private var note: String

    init(
        transaction: MoneyTransaction?,
        initialType: TransactionType,
        accounts: [Account],
        categories: [SpendingCategory]
    ) {
        self.transaction = transaction
        self.accounts = accounts
        self.categories = categories

        _type = State(initialValue: transaction?.type ?? initialType)
        _amount = State(initialValue: MoneyFormatting.rupeesText(fromPaise: transaction?.amountPaise ?? 0))
        _date = State(initialValue: transaction?.date ?? .now)
        _accountID = State(initialValue: transaction?.account?.persistentModelID ?? accounts.first?.persistentModelID)
        _destinationAccountID = State(initialValue: transaction?.destinationAccount?.persistentModelID ?? accounts.dropFirst().first?.persistentModelID)
        _categoryID = State(initialValue: transaction?.category?.persistentModelID ?? categories.first?.persistentModelID)
        _payee = State(initialValue: transaction?.payee ?? "")
        _note = State(initialValue: transaction?.note ?? "")
    }

    var body: some View {
        PaynoSheetScaffold(
            title: transaction == nil ? "Add \(type.title)" : "Edit \(type.title)",
            subtitle: "Record movement without leaving the flow.",
            primaryTitle: "Save",
            primaryDisabled: !canSave,
            onCancel: { dismiss() },
            onPrimary: save
        ) {
            SectionPanel(title: "Type", iconName: "arrow.up.arrow.down") {
                VStack(spacing: 12) {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { transactionType in
                            Text(transactionType.title).tag(transactionType)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            SectionPanel(title: "Details", iconName: "square.and.pencil") {
                VStack(spacing: 12) {
                    PaynoInputField(
                        title: "Amount",
                        placeholder: "0",
                        text: $amount,
                        keyboardType: .decimalPad
                    )

                    PaynoOptionRow(title: "Date") {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.moniLeaf)
                    }

                    PaynoOptionRow(title: type == .transfer ? "From" : "Account") {
                        Picker(type == .transfer ? "From" : "Account", selection: $accountID) {
                            ForEach(accounts) { account in
                                Text(account.name).tag(Optional(account.persistentModelID))
                            }
                        }
                        .labelsHidden()
                        .tint(Color.moniInk)
                    }

                    if type == .transfer {
                        PaynoOptionRow(title: "To") {
                            Picker("To", selection: $destinationAccountID) {
                                ForEach(accounts) { account in
                                    Text(account.name).tag(Optional(account.persistentModelID))
                                }
                            }
                            .labelsHidden()
                            .tint(Color.moniInk)
                        }
                    }

                    if type == .expense {
                        PaynoOptionRow(title: "Category") {
                            Picker("Category", selection: $categoryID) {
                                ForEach(categories) { category in
                                    Text(category.name).tag(Optional(category.persistentModelID))
                                }
                            }
                            .labelsHidden()
                            .tint(Color.moniInk)
                        }
                    }
                }
            }

            SectionPanel(title: "Optional", iconName: "text.alignleft") {
                VStack(spacing: 12) {
                    PaynoInputField(title: type == .expense ? "Payee" : "Label", placeholder: type == .expense ? "Payee" : "Label", text: $payee)
                    PaynoInputField(title: "Note", placeholder: "Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }

            if transaction != nil {
                Button("Delete transaction", role: .destructive) {
                    deleteTransaction()
                }
                .buttonStyle(PaynoDestructiveButtonStyle())
            }
        }
    }

    private var canSave: Bool {
        let amountPaise = MoneyFormatting.paise(from: amount)
        guard amountPaise > 0, selectedAccount != nil else { return false }

        if type == .expense {
            return selectedCategory != nil
        }

        if type == .transfer {
            return selectedDestinationAccount != nil && selectedDestinationAccount !== selectedAccount
        }

        return true
    }

    private var selectedAccount: Account? {
        accounts.first { Optional($0.persistentModelID) == accountID }
    }

    private var selectedDestinationAccount: Account? {
        accounts.first { Optional($0.persistentModelID) == destinationAccountID }
    }

    private var selectedCategory: SpendingCategory? {
        categories.first { Optional($0.persistentModelID) == categoryID }
    }

    private func save() {
        let amountPaise = MoneyFormatting.paise(from: amount)

        if let transaction {
            transaction.amountPaise = amountPaise
            transaction.date = date
            transaction.type = type
            transaction.account = selectedAccount
            transaction.destinationAccount = type == .transfer ? selectedDestinationAccount : nil
            transaction.category = type == .expense ? selectedCategory : nil
            transaction.payee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            modelContext.insert(
                MoneyTransaction(
                    amountPaise: amountPaise,
                    date: date,
                    type: type,
                    account: selectedAccount,
                    destinationAccount: type == .transfer ? selectedDestinationAccount : nil,
                    category: type == .expense ? selectedCategory : nil,
                    payee: payee.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        dismiss()
    }

    private func deleteTransaction() {
        if let transaction {
            modelContext.delete(transaction)
        }

        dismiss()
    }
}

private struct BudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [SpendingCategory]
    let budgets: [MonthlyBudget]

    @State private var totalBudget: String
    @State private var categoryBudgetTexts: [PersistentIdentifier: String]

    private let monthStart = Calendar.current.startOfMonth(for: .now)

    init(categories: [SpendingCategory], budgets: [MonthlyBudget]) {
        self.categories = categories
        self.budgets = budgets

        let currentTotal = budgets.first {
            Calendar.current.isDate($0.monthStart, inSameMonthAs: .now) && $0.category == nil
        }?.totalBudgetPaise ?? 0

        var categoryValues: [PersistentIdentifier: String] = [:]
        for category in categories {
            let budget = budgets.first {
                Calendar.current.isDate($0.monthStart, inSameMonthAs: .now)
                    && $0.category === category
            }
            categoryValues[category.persistentModelID] = MoneyFormatting.rupeesText(fromPaise: budget?.totalBudgetPaise ?? 0)
        }

        _totalBudget = State(initialValue: MoneyFormatting.rupeesText(fromPaise: currentTotal))
        _categoryBudgetTexts = State(initialValue: categoryValues)
    }

    var body: some View {
        PaynoSheetScaffold(
            title: "Budgets",
            subtitle: "Set this month’s total and category limits.",
            primaryTitle: "Save",
            onCancel: { dismiss() },
            onPrimary: save
        ) {
            SectionPanel(title: "Monthly total", iconName: "chart.pie") {
                PaynoInputField(
                    title: "Total budget",
                    placeholder: "0",
                    text: $totalBudget,
                    keyboardType: .decimalPad
                )
            }

            SectionPanel(title: "Categories", iconName: "tag") {
                VStack(spacing: 12) {
                    ForEach(categories) { category in
                        PaynoInputField(
                            title: category.name,
                            placeholder: "0",
                            text: binding(for: category),
                            keyboardType: .decimalPad
                        )
                    }
                }
            }
        }
    }

    private func binding(for category: SpendingCategory) -> Binding<String> {
        Binding(
            get: {
                categoryBudgetTexts[category.persistentModelID] ?? ""
            },
            set: {
                categoryBudgetTexts[category.persistentModelID] = $0
            }
        )
    }

    private func save() {
        upsertBudget(category: nil, amountPaise: MoneyFormatting.paise(from: totalBudget))

        for category in categories {
            upsertBudget(
                category: category,
                amountPaise: MoneyFormatting.paise(from: categoryBudgetTexts[category.persistentModelID] ?? "")
            )
        }

        dismiss()
    }

    private func upsertBudget(category: SpendingCategory?, amountPaise: Int) {
        let existing = budgets.first {
            Calendar.current.isDate($0.monthStart, inSameMonthAs: monthStart)
                && sameCategory($0.category, category)
        }

        if let existing {
            if amountPaise > 0 {
                existing.totalBudgetPaise = amountPaise
            } else {
                modelContext.delete(existing)
            }
        } else if amountPaise > 0 {
            modelContext.insert(
                MonthlyBudget(
                    monthStart: monthStart,
                    totalBudgetPaise: amountPaise,
                    category: category
                )
            )
        }
    }

    private func sameCategory(_ lhs: SpendingCategory?, _ rhs: SpendingCategory?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case let (.some(lhs), .some(rhs)):
            lhs === rhs
        default:
            false
        }
    }
}

private struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [SpendingCategory]
    @State private var newCategoryName = ""

    var body: some View {
        PaynoSheetScaffold(
            title: "Categories",
            subtitle: "Create and tune the categories used by quick expense.",
            primaryTitle: "Done",
            onPrimary: { dismiss() }
        ) {
            SectionPanel(title: "Add category", iconName: "plus") {
                HStack(spacing: 10) {
                    PaynoInputField(title: "Name", placeholder: "Category name", text: $newCategoryName)

                    VStack {
                        Spacer(minLength: 22)
                        Button {
                            addCategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(Color.moniLeaf)
                                .frame(width: 48, height: 48)
                                .background(Color.moniLeaf.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(MicroPressButtonStyle())
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            SectionPanel(title: "Categories", iconName: "tag") {
                if categories.isEmpty {
                    EmptyStatePanel(title: "No categories", subtitle: "Add a category to use quick expense.", iconName: "tag")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.element.persistentModelID) { index, category in
                            CategoryEditRow(category: category) {
                                deleteCategory(at: index)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addCategory() {
        let cleanedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }

        modelContext.insert(SpendingCategory(name: cleanedName))
        newCategoryName = ""
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }

    private func deleteCategory(at index: Int) {
        modelContext.delete(categories[index])
    }
}

private struct CategoryEditRow: View {
    let category: SpendingCategory
    let onDelete: () -> Void
    @State private var name: String

    init(category: SpendingCategory, onDelete: @escaping () -> Void) {
        self.category = category
        self.onDelete = onDelete
        _name = State(initialValue: category.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            PaynoInputField(title: "Category", placeholder: "Category", text: $name)
                .onSubmit {
                    category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .onChange(of: name) {
                    category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.moniCoral)
                    .frame(width: 44, height: 44)
                    .background(Color.moniCoral.opacity(0.10), in: Circle())
            }
            .buttonStyle(MicroPressButtonStyle())
            .padding(.top, 22)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Account.self,
                SpendingCategory.self,
                MoneyTransaction.self,
                MonthlyBudget.self
            ],
            inMemory: true
        )
}
