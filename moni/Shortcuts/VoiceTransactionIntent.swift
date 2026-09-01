//
//  VoiceTransactionIntent.swift
//  moni
//

import AppIntents
import Foundation

enum VoiceTransactionKind: String, AppEnum {
    case debit
    case credit

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Transaction Type")

    static var caseDisplayRepresentations: [VoiceTransactionKind: DisplayRepresentation] = [
        .debit: DisplayRepresentation(title: "Debit"),
        .credit: DisplayRepresentation(title: "Credit")
    ]

    var transactionType: TransactionType {
        switch self {
        case .debit:
            .expense
        case .credit:
            .income
        }
    }

    var payee: String {
        switch self {
        case .debit:
            "Voice debit"
        case .credit:
            "Voice credit"
        }
    }
}

struct AddVoiceDebitIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Debit"
    static var description = IntentDescription("Adds a debit expense to moni from Siri.")
    static var openAppWhenRun = false

    @Parameter(
        title: "Amount",
        description: "Debit amount in rupees.",
        requestValueDialog: "How much did you spend?"
    )
    var amount: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await VoiceTransactionSaver.save(kind: .debit, amount: amount)
    }
}

struct AddVoiceCreditIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Credit"
    static var description = IntentDescription("Adds a credit income transaction to moni from Siri.")
    static var openAppWhenRun = false

    @Parameter(
        title: "Amount",
        description: "Credit amount in rupees.",
        requestValueDialog: "How much did you receive?"
    )
    var amount: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await VoiceTransactionSaver.save(kind: .credit, amount: amount)
    }
}

private enum VoiceTransactionSaver {
    @MainActor
    static func save(kind: VoiceTransactionKind, amount: Double) async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Enter an amount greater than zero.")
        }

        let amountPaise = Int((amount * 100).rounded())

        do {
            try FinanceStore.addImportedTransaction(
                amountPaise: amountPaise,
                type: kind.transactionType,
                categoryName: kind == .debit ? "Uncategorized" : nil,
                payee: kind.payee,
                note: "Added with Siri"
            )

            return .result(
                dialog: "\(kind == .debit ? "Debit" : "Credit") of \(MoneyFormatting.display(amountPaise)) added."
            )
        } catch ShortcutExpenseError.noActiveAccount {
            return .result(dialog: "Open moni and create an account first.")
        }
    }
}
