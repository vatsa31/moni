//
//  FinanceCommands.swift
//  moni
//

import Foundation
import SwiftData

enum FinanceCommands {
    static let defaultCategoryNames = ["Food", "Groceries", "Transport", "Shopping", "Bills", "Health", "Entertainment", "Travel"]

    static func ensureDefaultCategories(existing categories: [SpendingCategory], in modelContext: ModelContext) {
        guard categories.isEmpty else { return }

        for name in defaultCategoryNames {
            modelContext.insert(SpendingCategory(name: name, isDefault: true))
        }
    }

    static func createInitialAccount(
        name: String,
        type: AccountType,
        openingBalanceText: String,
        monthlyBudgetText: String,
        existingCategories: [SpendingCategory],
        in modelContext: ModelContext
    ) {
        ensureDefaultCategories(existing: existingCategories, in: modelContext)

        modelContext.insert(
            Account(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                openingBalancePaise: MoneyFormatting.paise(from: openingBalanceText)
            )
        )

        let budgetPaise = MoneyFormatting.paise(from: monthlyBudgetText)
        guard budgetPaise > 0 else { return }

        modelContext.insert(
            MonthlyBudget(
                monthStart: Calendar.current.startOfMonth(for: .now),
                totalBudgetPaise: budgetPaise
            )
        )
    }

    static func saveAccount(
        _ account: Account?,
        name: String,
        type: AccountType,
        openingBalanceText: String,
        isArchived: Bool,
        in modelContext: ModelContext
    ) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let openingBalancePaise = MoneyFormatting.paise(from: openingBalanceText)

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
    }

    static func saveTransaction(
        _ transaction: MoneyTransaction?,
        amountText: String,
        date: Date,
        type: TransactionType,
        account: Account?,
        destinationAccount: Account?,
        category: SpendingCategory?,
        payee: String,
        note: String,
        in modelContext: ModelContext
    ) {
        let amountPaise = MoneyFormatting.paise(from: amountText)
        let cleanedPayee = payee.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDestination = type == .transfer ? destinationAccount : nil
        let resolvedCategory = type == .expense ? category : nil

        if let transaction {
            transaction.amountPaise = amountPaise
            transaction.date = date
            transaction.type = type
            transaction.account = account
            transaction.destinationAccount = resolvedDestination
            transaction.category = resolvedCategory
            transaction.payee = cleanedPayee
            transaction.note = cleanedNote
        } else {
            modelContext.insert(
                MoneyTransaction(
                    amountPaise: amountPaise,
                    date: date,
                    type: type,
                    account: account,
                    destinationAccount: resolvedDestination,
                    category: resolvedCategory,
                    payee: cleanedPayee,
                    note: cleanedNote
                )
            )
        }
    }

    static func saveQuickExpense(
        amountPaise: Int,
        category: SpendingCategory,
        account: Account,
        in modelContext: ModelContext
    ) {
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
    }

    static func saveBudgets(
        totalBudgetText: String,
        categoryBudgetTexts: [PersistentIdentifier: String],
        categories: [SpendingCategory],
        budgets: [MonthlyBudget],
        monthStart: Date,
        in modelContext: ModelContext
    ) {
        upsertBudget(
            category: nil,
            amountPaise: MoneyFormatting.paise(from: totalBudgetText),
            budgets: budgets,
            monthStart: monthStart,
            in: modelContext
        )

        for category in categories {
            upsertBudget(
                category: category,
                amountPaise: MoneyFormatting.paise(from: categoryBudgetTexts[category.persistentModelID] ?? ""),
                budgets: budgets,
                monthStart: monthStart,
                in: modelContext
            )
        }
    }

    static func addCategory(name: String, in modelContext: ModelContext) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }

        modelContext.insert(SpendingCategory(name: cleanedName))
    }

    static func delete(_ object: any PersistentModel, in modelContext: ModelContext) {
        modelContext.delete(object)
    }

    private static func upsertBudget(
        category: SpendingCategory?,
        amountPaise: Int,
        budgets: [MonthlyBudget],
        monthStart: Date,
        in modelContext: ModelContext
    ) {
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

    private static func sameCategory(_ lhs: SpendingCategory?, _ rhs: SpendingCategory?) -> Bool {
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
