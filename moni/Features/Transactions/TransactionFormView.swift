//
//  TransactionFormView.swift
//  moni
//

import SwiftData
import SwiftUI

struct TransactionFormView: View {
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
        _amount = State(initialValue: transaction.map { MoneyFormatting.rupeesText(fromPaise: $0.amountPaise) } ?? "")
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
                        placeholder: "Amount",
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
        FinanceCommands.saveTransaction(
            transaction,
            amountText: amount,
            date: date,
            type: type,
            account: selectedAccount,
            destinationAccount: selectedDestinationAccount,
            category: selectedCategory,
            payee: payee,
            note: note,
            in: modelContext
        )
        dismiss()
    }

    private func deleteTransaction() {
        if let transaction {
            modelContext.delete(transaction)
        }

        dismiss()
    }
}
