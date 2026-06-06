//
//  FinanceRows.swift
//  moni
//

import SwiftUI

struct AccountRowView: View {
    let account: Account
    let balancePaise: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.iconName)
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.moniInk)
                .frame(width: 42, height: 42)
                .background(accountAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(account.type.title)
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()

            Text(MoneyFormatting.display(balancePaise))
                .font(.headline.monospacedDigit())
                .foregroundStyle(balancePaise < 0 ? Color.moniCoral : Color.moniInk)
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private var accountAccent: Color {
        switch account.type {
        case .cash:
            Color.moniLime
        case .bank:
            Color.moniSky
        case .creditCard:
            Color.moniAmber
        }
    }
}

struct TransactionRowView: View {
    let transaction: MoneyTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.moniInk)
                .frame(width: 42, height: 42)
                .background(amountColor.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(transaction.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()

            Text(amountText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private var primaryText: String {
        if !transaction.payee.isEmpty {
            return transaction.payee
        }

        if transaction.type == .transfer {
            let source = transaction.account?.name ?? "Account"
            let destination = transaction.destinationAccount?.name ?? "Account"
            return "\(source) to \(destination)"
        }

        return transaction.category?.name ?? transaction.type.title
    }

    private var iconName: String {
        switch transaction.type {
        case .expense:
            "minus.circle"
        case .income:
            "plus.circle"
        case .transfer:
            "arrow.left.arrow.right"
        }
    }

    private var amountText: String {
        switch transaction.type {
        case .expense:
            "-\(MoneyFormatting.display(transaction.amountPaise))"
        case .income:
            "+\(MoneyFormatting.display(transaction.amountPaise))"
        case .transfer:
            MoneyFormatting.display(transaction.amountPaise)
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .expense:
            Color.moniCoral
        case .income:
            Color.moniLeaf
        case .transfer:
            Color.moniSky
        }
    }
}


struct CategoryBudgetRowView: View {
    let category: SpendingCategory
    let budgetPaise: Int
    let spentPaise: Int

    var body: some View {
        let state = FinanceCalculator.budgetState(spentPaise: spentPaise, budgetPaise: budgetPaise)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Spacer()
                Text("\(MoneyFormatting.display(spentPaise)) / \(MoneyFormatting.display(budgetPaise))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.moniMuted)
            }

            AnimatedProgressBar(
                progress: FinanceCalculator.progress(spentPaise: spentPaise, budgetPaise: budgetPaise),
                state: state
            )
        }
        .padding(12)
        .background(Color.moniSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }

    private func tint(for state: BudgetColorState) -> Color {
        switch state {
        case .neutral:
            .secondary
        case .green:
            .green
        case .yellow:
            .orange
        case .red:
            .red
        }
    }
}
