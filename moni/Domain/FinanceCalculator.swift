//
//  FinanceCalculator.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import Foundation

/// Pure calculations for balances, monthly totals and budget state.
enum FinanceCalculator {
    static func balance(for account: Account, transactions: [MoneyTransaction]) -> Int {
        transactions.reduce(account.openingBalancePaise) { runningBalance, transaction in
            runningBalance + impact(of: transaction, on: account)
        }
    }

    static func monthlyExpenses(
        in transactions: [MoneyTransaction],
        month: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        transactions
            .filter { $0.type == .expense && calendar.isDate($0.date, inSameMonthAs: month) }
            .reduce(0) { $0 + $1.amountPaise }
    }

    static func monthlyExpenses(
        in transactions: [MoneyTransaction],
        category: SpendingCategory,
        month: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        transactions
            .filter {
                $0.type == .expense
                    && calendar.isDate($0.date, inSameMonthAs: month)
                    && $0.category === category
            }
            .reduce(0) { $0 + $1.amountPaise }
    }

    static func budgetState(spentPaise: Int, budgetPaise: Int) -> BudgetColorState {
        guard budgetPaise > 0 else { return .neutral }

        let ratio = Double(spentPaise) / Double(budgetPaise)
        if ratio >= 1 {
            return .red
        }
        if ratio >= 0.75 {
            return .yellow
        }
        return .green
    }

    static func progress(spentPaise: Int, budgetPaise: Int) -> Double {
        guard budgetPaise > 0 else { return 0 }
        return min(Double(spentPaise) / Double(budgetPaise), 1)
    }

    // MARK: - Private

    private static func impact(of transaction: MoneyTransaction, on account: Account) -> Int {
        let amount = transaction.amountPaise

        switch transaction.type {
        case .expense:
            return transaction.account === account ? -amount : 0
        case .income:
            return transaction.account === account ? amount : 0
        case .transfer:
            if transaction.account === account {
                return -amount
            }
            if transaction.destinationAccount === account {
                return amount
            }
            return 0
        }
    }
}

