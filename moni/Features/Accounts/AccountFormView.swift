//
//  AccountFormView.swift
//  moni
//

import SwiftData
import SwiftUI

struct AccountFormView: View {
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
        FinanceCommands.saveAccount(
            account,
            name: name,
            type: type,
            openingBalanceText: openingBalance,
            isArchived: isArchived,
            in: modelContext
        )
        dismiss()
    }
}
