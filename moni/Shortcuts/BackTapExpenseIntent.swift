//
//  BackTapExpenseIntent.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 06/06/26.
//

import AppIntents
import Foundation
import SwiftUI

struct AddBackTapExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Expense"
    static var description = IntentDescription("Asks for an amount and shows a category picker.")
    static var openAppWhenRun = false

    @Parameter(
        title: "Amount",
        description: "Expense amount in rupees",
        requestValueDialog: "What is the quick expense amount?"
    )
    var amount: Double

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        guard amount > 0 else {
            return .result(view: Text("Enter an amount greater than zero."))
        }

        return .result(
            view: ShortcutCategoryPickerSnippet(
                amountPaise: Int((amount * 100).rounded()),
                formattedAmount: formattedAmount
            )
        )
    }

    private var formattedAmount: String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct SaveShortcutExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Expense"
    static var description = IntentDescription("Saves a Back Tap expense in the selected category.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount")
    var amountPaise: Int

    @Parameter(title: "Category")
    var categoryName: String

    init() {
        amountPaise = 0
        categoryName = ""
    }

    init(amountPaise: Int, categoryName: String) {
        self.amountPaise = amountPaise
        self.categoryName = categoryName
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try FinanceStore.addShortcutExpense(amountPaise: amountPaise, categoryName: categoryName)
            return .result(dialog: "Saved \(MoneyFormatting.display(amountPaise)) for \(categoryName).")
        } catch ShortcutExpenseError.noActiveAccount {
            return .result(dialog: "Open moni and create an account first.")
        }
    }
}

private struct ShortcutCategoryPickerSnippet: View {
    @Environment(\.colorScheme) private var colorScheme

    let amountPaise: Int
    let formattedAmount: String

    var body: some View {
        VStack(spacing: 14) {
            header

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                ForEach(FinanceStore.shortcutCategoryNames, id: \.self) { categoryName in
                    Button(intent: SaveShortcutExpenseIntent(amountPaise: amountPaise, categoryName: categoryName)) {
                        categoryTile(for: categoryName)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(snippetBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(headerIconBackground)
                    .frame(width: 46, height: 46)

                Image(systemName: "indianrupeesign")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(headerIconForeground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Choose category")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("INR \(formattedAmount)")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(headerBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func categoryTile(for categoryName: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: iconName(for: categoryName))
                .font(.title3.weight(.semibold))
                .foregroundStyle(tileIconColor)
                .frame(width: 34, height: 34)
                .background(tileIconBackground, in: Circle())

            Text(categoryName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.horizontal, 8)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tileStroke, lineWidth: 1)
        }
    }

    private var snippetBackground: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.12, green: 0.13, blue: 0.14), Color(red: 0.06, green: 0.07, blue: 0.08)]
                : [Color(.secondarySystemBackground), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerBackground: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.045)
    }

    private var headerIconBackground: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08)
    }

    private var headerIconForeground: Color {
        colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.82)
    }

    private var tileBackground: Color {
        colorScheme == .dark ? .white.opacity(0.075) : .white.opacity(0.86)
    }

    private var tileStroke: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.06)
    }

    private var tileIconBackground: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.055)
    }

    private var tileIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.78)
    }

    private func iconName(for categoryName: String) -> String {
        switch categoryName.lowercased() {
        case "food":
            "fork.knife"
        case "groceries":
            "cart"
        case "transport":
            "car"
        case "shopping":
            "bag"
        case "bills":
            "doc.text"
        default:
            "tag"
        }
    }
}

struct MoniAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddVoiceDebitIntent(),
            phrases: [
                "Add debit in \(.applicationName)",
                "Add debit to \(.applicationName)",
                "Log debit in \(.applicationName)"
            ],
            shortTitle: "Add Debit",
            systemImageName: "arrow.up.circle"
        )
        AppShortcut(
            intent: AddVoiceCreditIntent(),
            phrases: [
                "Add credit in \(.applicationName)",
                "Add credit to \(.applicationName)",
                "Log credit in \(.applicationName)"
            ],
            shortTitle: "Add Credit",
            systemImageName: "arrow.down.circle"
        )
    }
}
