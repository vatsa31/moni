//
//  ContentView.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Namespace var tabSelectionNamespace

    @Query(sort: \Account.createdAt) var accounts: [Account]
    @Query(sort: \SpendingCategory.name) var categories: [SpendingCategory]
    @Query(sort: \MoneyTransaction.date, order: .reverse) var transactions: [MoneyTransaction]
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) var budgets: [MonthlyBudget]

    @AppStorage("appTheme") var appThemeRawValue = AppTheme.system.rawValue
    @AppStorage(ThemeStorageKey.useCustomTheme) var useCustomTheme = false
    @AppStorage(ThemeStorageKey.customThemeJSON) var customThemeJSON = ""
    @State var activeSheet: ActiveSheet?
    @State var selectedTab: AppTab = .home
    @State var quickAmountPaise = 1_000
    @State var quickDragHeight: CGFloat = 0
    @State var isChoosingQuickAmount = false
    @State var quickPickerAmountPaise: Int?
    @State var categoryDragOffset: CGSize = .zero
    @State var highlightedQuickCategoryID: PersistentIdentifier?
    @State var lastQuickDragHapticTime: TimeInterval = 0
    @State var lastCategoryDragHapticTime: TimeInterval = 0
    @State var dashboardAppeared = false

    let quickExpenseLadder = [10, 20, 50, 100, 200, 500, 1_000, 1_500, 2_000, 3_000, 4_000, 5_000]
    let dragHapticInterval: TimeInterval = 0.08

    init() {}

    var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    var activeAccounts: [Account] {
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
            case .themeBuilder:
                ThemeBuilderView()
            }
        }
    }

    var themeMenu: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    appThemeRawValue = theme.rawValue
                } label: {
                    Label(theme.title, systemImage: theme == appTheme ? "checkmark" : theme.iconName)
                }
            }

            Divider()

            Button {
                activeSheet = .themeBuilder
            } label: {
                Label("Customize theme", systemImage: "paintpalette")
            }
        } label: {
            Label("Theme", systemImage: appTheme.iconName)
        }
        .accessibilityLabel("Theme")
    }

    @ViewBuilder
    var currentContent: some View {
        switch selectedTab {
        case .home:
            dashboard
        case .history:
            history
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
