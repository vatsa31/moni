//
//  BudgetFormView.swift
//  moni
//

import SwiftData
import SwiftUI

struct BudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [SpendingCategory]
    let budgets: [MonthlyBudget]

    @State private var totalBudget: String
    @State private var categoryBudgetTexts: [PersistentIdentifier: String]

    private let monthStart = Calendar.current.startOfMonth(for: .now)

    init(categories: [SpendingCategory], budgets: [MonthlyBudget]) {
        self.categories = categories
        self.budgets = budgets

        let currentTotal = budgets.first {
            Calendar.current.isDate($0.monthStart, inSameMonthAs: .now) && $0.category == nil
        }?.totalBudgetPaise ?? 0

        var categoryValues: [PersistentIdentifier: String] = [:]
        for category in categories {
            let budget = budgets.first {
                Calendar.current.isDate($0.monthStart, inSameMonthAs: .now)
                    && $0.category === category
            }
            categoryValues[category.persistentModelID] = budget.map { MoneyFormatting.rupeesText(fromPaise: $0.totalBudgetPaise) } ?? ""
        }

        _totalBudget = State(initialValue: currentTotal > 0 ? MoneyFormatting.rupeesText(fromPaise: currentTotal) : "")
        _categoryBudgetTexts = State(initialValue: categoryValues)
    }

    var body: some View {
        PaynoSheetScaffold(
            title: "Budgets",
            subtitle: "Set this month’s total and category limits.",
            primaryTitle: "Save",
            onCancel: { dismiss() },
            onPrimary: save
        ) {
            SectionPanel(title: "Monthly total", iconName: "chart.pie") {
                PaynoInputField(
                    title: "Total budget",
                    placeholder: "Monthly budget",
                    text: $totalBudget,
                    keyboardType: .decimalPad
                )
            }

            SectionPanel(title: "Categories", iconName: "tag") {
                VStack(spacing: 12) {
                    ForEach(categories) { category in
                        PaynoInputField(
                            title: category.name,
                            placeholder: "Category budget",
                            text: binding(for: category),
                            keyboardType: .decimalPad
                        )
                    }
                }
            }
        }
    }

    private func binding(for category: SpendingCategory) -> Binding<String> {
        Binding(
            get: {
                categoryBudgetTexts[category.persistentModelID] ?? ""
            },
            set: {
                categoryBudgetTexts[category.persistentModelID] = $0
            }
        )
    }

    private func save() {
        FinanceCommands.saveBudgets(
            totalBudgetText: totalBudget,
            categoryBudgetTexts: categoryBudgetTexts,
            categories: categories,
            budgets: budgets,
            monthStart: monthStart,
            in: modelContext
        )
        dismiss()
    }
}
