//
//  BackTapExpenseIntent.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 06/06/26.
//

import AppIntents
import Foundation

struct AddBackTapExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Asks for an amount, opens moni, and lets you choose a category.")
    static var openAppWhenRun = true

    @Parameter(
        title: "Amount",
        description: "Expense amount in rupees",
        requestValueDialog: "How much did you spend?"
    )
    var amount: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Enter an amount greater than zero.")
        }

        FinanceStore.setPendingBackTapExpense(amountRupees: amount)
        return .result(dialog: "Choose a category for INR \(formattedAmount).")
    }

    private var formattedAmount: String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct MoniAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddBackTapExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "indianrupeesign.circle"
        )
    }
}
