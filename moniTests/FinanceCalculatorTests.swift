//
//  FinanceCalculatorTests.swift
//  moniTests
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import Foundation
import Testing
@testable import moni

struct FinanceCalculatorTests {
    @Test func cashAndBankBalancesReflectExpensesIncomeAndTransfers() {
        let cash = Account(name: "Cash", type: .cash, openingBalancePaise: 10_000)
        let bank = Account(name: "Bank", type: .bank, openingBalancePaise: 100_000)
        let food = SpendingCategory(name: "Food", isDefault: true)

        let transactions = [
            MoneyTransaction(amountPaise: 2_500, type: .expense, account: cash, category: food),
            MoneyTransaction(amountPaise: 25_000, type: .income, account: bank),
            MoneyTransaction(amountPaise: 10_000, type: .transfer, account: bank, destinationAccount: cash)
        ]

        #expect(FinanceCalculator.balance(for: cash, transactions: transactions) == 17_500)
        #expect(FinanceCalculator.balance(for: bank, transactions: transactions) == 115_000)
    }

    @Test func creditCardPurchasesIncreaseDebtAndPaymentsReduceDebt() {
        let bank = Account(name: "Bank", type: .bank, openingBalancePaise: 80_000)
        let card = Account(name: "Card", type: .creditCard, openingBalancePaise: -15_000)
        let shopping = SpendingCategory(name: "Shopping", isDefault: true)

        let transactions = [
            MoneyTransaction(amountPaise: 5_000, type: .expense, account: card, category: shopping),
            MoneyTransaction(amountPaise: 12_000, type: .transfer, account: bank, destinationAccount: card)
        ]

        #expect(FinanceCalculator.balance(for: card, transactions: transactions) == -8_000)
        #expect(FinanceCalculator.balance(for: bank, transactions: transactions) == 68_000)
    }

    @Test func editedAndDeletedTransactionsRecalculateBalancesFromCurrentList() {
        let bank = Account(name: "Bank", type: .bank, openingBalancePaise: 50_000)
        let food = SpendingCategory(name: "Food", isDefault: true)
        let expense = MoneyTransaction(amountPaise: 10_000, type: .expense, account: bank, category: food)
        let income = MoneyTransaction(amountPaise: 25_000, type: .income, account: bank)

        var transactions = [expense, income]
        #expect(FinanceCalculator.balance(for: bank, transactions: transactions) == 65_000)

        expense.amountPaise = 15_000
        #expect(FinanceCalculator.balance(for: bank, transactions: transactions) == 60_000)

        transactions.removeAll { $0 === income }
        #expect(FinanceCalculator.balance(for: bank, transactions: transactions) == 35_000)
    }

    @Test func monthlyExpenseTotalsIgnoreIncomeTransfersAndOtherMonths() {
        let bank = Account(name: "Bank", type: .bank, openingBalancePaise: 0)
        let food = SpendingCategory(name: "Food", isDefault: true)
        let calendar = Calendar(identifier: .gregorian)
        let june = DateComponents(calendar: calendar, year: 2026, month: 6, day: 5).date!
        let may = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28).date!

        let transactions = [
            MoneyTransaction(amountPaise: 1_000, date: june, type: .expense, account: bank, category: food),
            MoneyTransaction(amountPaise: 2_000, date: june, type: .income, account: bank),
            MoneyTransaction(amountPaise: 3_000, date: june, type: .transfer, account: bank, destinationAccount: nil),
            MoneyTransaction(amountPaise: 4_000, date: may, type: .expense, account: bank, category: food)
        ]

        #expect(
            FinanceCalculator.monthlyExpenses(
                in: transactions,
                month: june,
                calendar: calendar
            ) == 1_000
        )
    }

    @Test func budgetColorStatesUseConfiguredMonthlyBudget() {
        #expect(FinanceCalculator.budgetState(spentPaise: 0, budgetPaise: 0) == .neutral)
        #expect(FinanceCalculator.budgetState(spentPaise: 7_400, budgetPaise: 10_000) == .green)
        #expect(FinanceCalculator.budgetState(spentPaise: 7_500, budgetPaise: 10_000) == .yellow)
        #expect(FinanceCalculator.budgetState(spentPaise: 10_000, budgetPaise: 10_000) == .red)
        #expect(FinanceCalculator.budgetState(spentPaise: 11_000, budgetPaise: 10_000) == .red)
    }
}

