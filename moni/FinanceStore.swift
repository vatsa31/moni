//
//  FinanceStore.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 06/06/26.
//

import Foundation
import SwiftData

enum FinanceStore {
    private static let pendingBackTapExpenseAmountKey = "pendingBackTapExpenseAmountPaise"

    static let schema = Schema([
        Account.self,
        SpendingCategory.self,
        MoneyTransaction.self,
        MonthlyBudget.self,
    ])

    static let sharedModelContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func setPendingBackTapExpense(amountRupees: Double) {
        UserDefaults.standard.set(Int((amountRupees * 100).rounded()), forKey: pendingBackTapExpenseAmountKey)
    }

    static func consumePendingBackTapExpensePaise() -> Int? {
        let amountPaise = UserDefaults.standard.integer(forKey: pendingBackTapExpenseAmountKey)
        guard amountPaise > 0 else { return nil }

        UserDefaults.standard.removeObject(forKey: pendingBackTapExpenseAmountKey)
        return amountPaise
    }
}
