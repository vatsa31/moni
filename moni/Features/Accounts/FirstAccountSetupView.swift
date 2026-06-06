//
//  FirstAccountSetupView.swift
//  moni
//

import SwiftData
import SwiftUI

struct FirstAccountSetupView: View {
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
        FinanceCommands.createInitialAccount(
            name: name,
            type: type,
            openingBalanceText: openingBalance,
            monthlyBudgetText: monthlyBudget,
            existingCategories: categories,
            in: modelContext
        )
    }
}
