//
//  FinanceStore.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 06/06/26.
//

import Foundation
import SwiftData

/// Central persistence boundary for SwiftData + Shortcuts bridge.
enum FinanceStore {
    private static let pendingBackTapExpenseAmountKey = "pendingBackTapExpenseAmountPaise"
    static let shortcutCategoryNames = ["Food", "Groceries", "Transport", "Shopping", "Bills"]

    static let schema = Schema([
        Account.self,
        SpendingCategory.self,
        MoneyTransaction.self,
        MonthlyBudget.self,
    ])

    // MARK: - Model Container

    /// Shared persistent container. Falls back to in-memory store if disk store fails (e.g. migration error).
    static let sharedModelContainer: ModelContainer = {
        let diskConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [diskConfig])
        } catch {
            assertionFailure("Failed to create disk ModelContainer: \(error). Falling back to in-memory store.")
            #if DEBUG
            print("[FinanceStore] Disk store failed: \(error.localizedDescription)")
            #endif
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // In-memory fallback should never throw; if it does, surface as precondition in DEBUG.
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                preconditionFailure("Unable to create in-memory ModelContainer: \(error)")
            }
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

    // MARK: - Shortcuts / Intents

    @MainActor
    static func addShortcutExpense(amountPaise: Int, categoryName: String) throws {
        let context = sharedModelContainer.mainContext
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { account in
                account.isArchived == false
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let account = try context.fetch(accountDescriptor).first else {
            throw ShortcutExpenseError.noActiveAccount
        }

        let category = try category(named: categoryName, in: context)

        context.insert(
            MoneyTransaction(
                amountPaise: amountPaise,
                date: .now,
                type: .expense,
                account: account,
                category: category,
                payee: category.name,
                note: "Added from Back Tap"
            )
        )

        try context.save()
    }

    @MainActor
    static func addImportedTransaction(
        amountPaise: Int,
        type: TransactionType,
        categoryName: String?,
        payee: String,
        note: String
    ) throws {
        let context = sharedModelContainer.mainContext
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { account in
                account.isArchived == false
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let account = try context.fetch(accountDescriptor).first else {
            throw ShortcutExpenseError.noActiveAccount
        }

        let resolvedCategory: SpendingCategory?
        if type == .expense, let categoryName {
            resolvedCategory = try category(named: categoryName, in: context)
        } else {
            resolvedCategory = nil
        }

        context.insert(
            MoneyTransaction(
                amountPaise: amountPaise,
                date: .now,
                type: type,
                account: account,
                category: resolvedCategory,
                payee: payee,
                note: note
            )
        )

        try context.save()
    }

    @MainActor
    private static func category(named categoryName: String, in context: ModelContext) throws -> SpendingCategory {
        let descriptor = FetchDescriptor<SpendingCategory>(
            predicate: #Predicate { category in
                category.name == categoryName
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        if let category = try context.fetch(descriptor).first {
            return category
        }

        let category = SpendingCategory(name: categoryName, isDefault: true)
        context.insert(category)
        return category
    }
}

enum ShortcutExpenseError: LocalizedError {
    case noActiveAccount

    var errorDescription: String? {
        switch self {
        case .noActiveAccount:
            "Create an account in moni before using Back Tap."
        }
    }
}
