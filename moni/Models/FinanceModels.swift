//
//  FinanceModels.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import Foundation
import SwiftData

// MARK: - Account Type

/// Supported account kinds.
enum AccountType: String, CaseIterable, Codable, Identifiable {
    case cash
    case bank
    case creditCard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank"
        case .creditCard:
            "Credit Card"
        }
    }

    var iconName: String {
        switch self {
        case .cash:
            "indianrupeesign.circle"
        case .bank:
            "building.columns"
        case .creditCard:
            "creditcard"
        }
    }
}

// MARK: - Transaction Type

enum TransactionType: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense:
            "Expense"
        case .income:
            "Income"
        case .transfer:
            "Transfer"
        }
    }
}

// MARK: - Budget State

enum BudgetColorState: Equatable {
    case neutral
    case green
    case yellow
    case red
}

// MARK: - SwiftData Models

/// SwiftData model for a financial account.
@Model
final class Account {
    var name: String
    var typeRawValue: String
    var openingBalancePaise: Int
    var isArchived: Bool
    var createdAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .cash }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        type: AccountType,
        openingBalancePaise: Int,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.openingBalancePaise = openingBalancePaise
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

@Model
final class SpendingCategory {
    var name: String
    var isDefault: Bool
    var createdAt: Date

    init(name: String, isDefault: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

@Model
final class MoneyTransaction {
    var amountPaise: Int
    var date: Date
    var typeRawValue: String
    var note: String
    var payee: String
    var account: Account?
    var destinationAccount: Account?
    var category: SpendingCategory?
    var createdAt: Date

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        amountPaise: Int,
        date: Date = .now,
        type: TransactionType,
        account: Account?,
        destinationAccount: Account? = nil,
        category: SpendingCategory? = nil,
        payee: String = "",
        note: String = "",
        createdAt: Date = .now
    ) {
        self.amountPaise = amountPaise
        self.date = date
        self.typeRawValue = type.rawValue
        self.account = account
        self.destinationAccount = destinationAccount
        self.category = category
        self.payee = payee
        self.note = note
        self.createdAt = createdAt
    }
}

@Model
final class MonthlyBudget {
    var monthStart: Date
    var totalBudgetPaise: Int
    var category: SpendingCategory?

    init(monthStart: Date, totalBudgetPaise: Int, category: SpendingCategory? = nil) {
        self.monthStart = Calendar.current.startOfMonth(for: monthStart)
        self.totalBudgetPaise = totalBudgetPaise
        self.category = category
    }
}

// MARK: - Calendar Helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    func isDate(_ date: Date, inSameMonthAs monthDate: Date) -> Bool {
        isDate(date, equalTo: monthDate, toGranularity: .month)
    }
}

