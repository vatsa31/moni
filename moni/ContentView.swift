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

    private let quickExpenseLadder = [10, 20, 50, 100, 200, 500, 1_000, 1_500, 2_000, 3_000, 4_000, 5_000]

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
                        .navigationTitle(selectedTab.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                themeMenu
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    activeSheet = .budget
                                } label: {
                                    Label("Budget", systemImage: "gauge.with.dots.needle.33percent")
                                }
                            }
                        }
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
        HStack {
            Button {
                selectedTab = .home
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .home ? "house.fill" : "house")
                        .font(.title3)
                    Text("Home")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(selectedTab == .home ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            quickExpenseButton

            Button {
                selectedTab = .history
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .history ? "clock.fill" : "clock")
                        .font(.title3)
                    Text("History")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(selectedTab == .history ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.regularMaterial)
    }

    private var quickExpenseButton: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.bold))
            .foregroundStyle(.background)
            .frame(width: 58, height: 58)
            .background(.primary, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .scaleEffect(isChoosingQuickAmount ? 1.08 : 1)
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
                            triggerSelectionHaptic()
                        }
                        quickAmountPaise = nextAmountPaise
                    }
                    .onEnded { value in
                        let upwardDrag = max(-value.translation.height, 0)

                        if upwardDrag > 24, !quickExpenseCategories.isEmpty {
                            triggerImpactHaptic()
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
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isChoosingQuickAmount)
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
                        triggerSelectionHaptic()
                    }
                    highlightedQuickCategoryID = nextCategoryID
                },
                onDrop: { dragLocation, categoryCenters in
                    if let categoryID = closestCategoryID(to: dragLocation, in: categoryCenters, maximumDistance: 96),
                       let category = categories.first(where: { $0.persistentModelID == categoryID }) {
                        triggerImpactHaptic()
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
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    VStack(spacing: 8) {
                        ForEach(quickExpenseLadder.reversed(), id: \.self) { amount in
                            HStack(spacing: 8) {
                                Capsule()
                                    .fill(amount * 100 <= quickAmountPaise ? Color.primary : Color.secondary.opacity(0.24))
                                    .frame(width: amount == selectedQuickAmountRupees ? 34 : 16, height: 5)

                                if amount == selectedQuickAmountRupees {
                                    Text(MoneyFormatting.display(amount * 100))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
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

        return List {
            Section {
                VStack(spacing: 18) {
                    HStack(alignment: .top) {
                        Spacer(minLength: 44)
                        VStack(spacing: 6) {
                            Text("This month")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(MoneyFormatting.display(monthlySpent))
                                .font(.largeTitle.bold())
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                                .multilineTextAlignment(.center)
                            Text("spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            activeSheet = .budget
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Edit budget")
                    }

                    if let totalBudget {
                        ProgressView(
                            value: budgetProgress
                        )
                        .tint(color(for: budgetState))

                        HStack {
                            Text("\(MoneyFormatting.display(max(totalBudget.totalBudgetPaise - monthlySpent, 0))) left")
                            Spacer()
                            Text("Budget \(MoneyFormatting.display(totalBudget.totalBudgetPaise))")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        Text("Set a monthly budget to grade spending.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: ambientColors(progress: budgetProgress, state: budgetState),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: ambientShadowColor(for: budgetState), radius: 18, y: 8)
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section("Accounts") {
                ForEach(activeAccounts) { account in
                    Button {
                        activeSheet = .account(account)
                    } label: {
                        AccountRowView(
                            account: account,
                            balancePaise: FinanceCalculator.balance(for: account, transactions: transactions)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    activeSheet = .account(nil)
                } label: {
                    Label("Add account", systemImage: "plus.circle")
                }
            }

            Section("Recent transactions") {
                let recentTransactions = transactions.prefix(8)

                if recentTransactions.isEmpty {
                    ContentUnavailableView(
                        "No transactions yet",
                        systemImage: "tray",
                        description: Text("Add an expense or income to start tracking.")
                    )
                } else {
                    ForEach(Array(recentTransactions)) { transaction in
                        Button {
                            activeSheet = .transaction(type: transaction.type, transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }

            Section("Category budgets") {
                let categoryBudgets = budgetsForMonth(monthStart).filter { $0.category != nil }

                if categoryBudgets.isEmpty {
                    Text("No category budgets set.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categoryBudgets) { budget in
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
                        }
                    }
                }

                Button {
                    activeSheet = .categories
                } label: {
                    Label("Manage categories", systemImage: "tag")
                }
            }
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
        List {
            Section("All transactions") {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No transactions yet",
                        systemImage: "clock",
                        description: Text("Tap the plus button to add an expense.")
                    )
                } else {
                    ForEach(transactions) { transaction in
                        Button {
                            activeSheet = .transaction(type: transaction.type, transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteHistoryTransactions)
                }
            }
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

    private func triggerSelectionHaptic() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func triggerImpactHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
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
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)
                Text(account.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(MoneyFormatting.display(balancePaise))
                .font(.headline.monospacedDigit())
                .foregroundStyle(balancePaise < 0 ? .red : .primary)
        }
    }
}

private struct TransactionRowView: View {
    let transaction: MoneyTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.headline)
                Text(transaction.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(amountText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(amountColor)
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
            .red
        case .income:
            .green
        case .transfer:
            .secondary
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
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                            .animation(.easeOut(duration: 0.14), value: isHighlighted)

                        if let iconPoint = centers[category.persistentModelID] {
                            Image(systemName: categoryIconName(for: category))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                                .frame(width: 46, height: 46)
                                .background(isHighlighted ? Color.primary : Color(.systemBackground), in: Circle())
                                .position(
                                    x: iconPoint.x - center.x + ringSize / 2,
                                    y: iconPoint.y - center.y + ringSize / 2
                                )
                        }
                    }

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: ringSize * 0.44, height: ringSize * 0.44)
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
                .frame(width: ringSize, height: ringSize)
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
                .position(center)

                Text(MoneyFormatting.display(amountPaise))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
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
        isHighlighted ? Color.primary.opacity(0.18) : Color(.secondarySystemBackground)
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
                    .font(.headline)
                Spacer()
                Text("\(MoneyFormatting.display(spentPaise)) / \(MoneyFormatting.display(budgetPaise))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: FinanceCalculator.progress(spentPaise: spentPaise, budgetPaise: budgetPaise))
                .tint(tint(for: state))
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

private struct FirstAccountSetupView: View {
    @Environment(\.modelContext) private var modelContext
    let categories: [SpendingCategory]

    @State private var name = "Main account"
    @State private var type: AccountType = .bank
    @State private var openingBalance = ""
    @State private var monthlyBudget = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("First account") {
                    TextField("Account name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { accountType in
                            Label(accountType.title, systemImage: accountType.iconName)
                                .tag(accountType)
                        }
                    }

                    TextField("Opening balance", text: $openingBalance)
                        .keyboardType(.decimalPad)
                }

                Section("Monthly budget") {
                    TextField("Total monthly budget", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Start tracking") {
                        createAccount()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Set up Moni")
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
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { accountType in
                            Label(accountType.title, systemImage: accountType.iconName)
                                .tag(accountType)
                        }
                    }

                    TextField("Opening balance", text: $openingBalance)
                        .keyboardType(.decimalPad)

                    if account != nil {
                        Toggle("Archived", isOn: $isArchived)
                    }
                }
            }
            .navigationTitle(account == nil ? "Add account" : "Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { transactionType in
                            Text(transactionType.title).tag(transactionType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Picker(type == .transfer ? "From" : "Account", selection: $accountID) {
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account.persistentModelID))
                        }
                    }

                    if type == .transfer {
                        Picker("To", selection: $destinationAccountID) {
                            ForEach(accounts) { account in
                                Text(account.name).tag(Optional(account.persistentModelID))
                            }
                        }
                    }

                    if type == .expense {
                        Picker("Category", selection: $categoryID) {
                            ForEach(categories) { category in
                                Text(category.name).tag(Optional(category.persistentModelID))
                            }
                        }
                    }
                }

                Section("Optional") {
                    TextField(type == .expense ? "Payee" : "Label", text: $payee)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if transaction != nil {
                    Section {
                        Button("Delete transaction", role: .destructive) {
                            deleteTransaction()
                        }
                    }
                }
            }
            .navigationTitle(transaction == nil ? "Add \(type.title)" : "Edit \(type.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
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
        NavigationStack {
            Form {
                Section("Monthly total") {
                    TextField("Total budget", text: $totalBudget)
                        .keyboardType(.decimalPad)
                }

                Section("Categories") {
                    ForEach(categories) { category in
                        TextField(
                            category.name,
                            text: binding(for: category)
                        )
                        .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
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
        NavigationStack {
            List {
                Section("Add category") {
                    HStack {
                        TextField("Category name", text: $newCategoryName)

                        Button {
                            addCategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Categories") {
                    ForEach(categories) { category in
                        CategoryEditRow(category: category)
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
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
}

private struct CategoryEditRow: View {
    let category: SpendingCategory
    @State private var name: String

    init(category: SpendingCategory) {
        self.category = category
        _name = State(initialValue: category.name)
    }

    var body: some View {
        TextField("Category", text: $name)
            .onSubmit {
                category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .onChange(of: name) {
                category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
