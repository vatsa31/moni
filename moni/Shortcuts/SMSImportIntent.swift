//
//  SMSImportIntent.swift
//  moni
//

import AppIntents
import SwiftUI

struct ImportTransactionFromSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Transaction from SMS"
    static var description = IntentDescription("Parses a bank SMS and adds the debit or credit transaction to moni.")
    static var openAppWhenRun = false

    @Parameter(
        title: "Message Text",
        description: "The SMS content from a Shortcuts message automation."
    )
    var messageText: String

    @Parameter(
        title: "Review Expense Category",
        description: "Show a category picker before saving expenses."
    )
    var reviewExpenseCategory: Bool

    init() {
        messageText = ""
        reviewExpenseCategory = false
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        guard let parsed = TransactionSMSParser.parse(messageText) else {
            return .result(
                view: SMSImportResultSnippet(
                    title: "Could not import",
                    subtitle: "No clear debit or credit amount was found.",
                    systemImageName: "exclamationmark.triangle"
                )
            )
        }

        if parsed.type == .expense && reviewExpenseCategory {
            return .result(
                view: SMSCategoryReviewSnippet(parsedTransaction: parsed)
            )
        }

        do {
            try FinanceStore.addImportedTransaction(
                amountPaise: parsed.amountPaise,
                type: parsed.type,
                categoryName: parsed.categoryName ?? "Uncategorized",
                payee: parsed.payee,
                note: "Imported from SMS"
            )

            return .result(
                view: SMSImportResultSnippet(
                    title: parsed.type == .income ? "Credit imported" : "Debit imported",
                    subtitle: "\(MoneyFormatting.display(parsed.amountPaise)) • \(parsed.payee)",
                    systemImageName: parsed.type == .income ? "arrow.down.circle" : "arrow.up.circle"
                )
            )
        } catch ShortcutExpenseError.noActiveAccount {
            return .result(
                view: SMSImportResultSnippet(
                    title: "Open moni first",
                    subtitle: "Create an account before importing SMS transactions.",
                    systemImageName: "person.crop.circle.badge.exclamationmark"
                )
            )
        }
    }
}

struct SaveImportedSMSTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Save SMS Transaction"
    static var description = IntentDescription("Saves a parsed SMS transaction with the selected category.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount")
    var amountPaise: Int

    @Parameter(title: "Type")
    var transactionTypeRawValue: String

    @Parameter(title: "Category")
    var categoryName: String

    @Parameter(title: "Payee")
    var payee: String

    init() {
        amountPaise = 0
        transactionTypeRawValue = TransactionType.expense.rawValue
        categoryName = "Uncategorized"
        payee = ""
    }

    init(parsedTransaction: ParsedSMSTransaction, categoryName: String) {
        amountPaise = parsedTransaction.amountPaise
        transactionTypeRawValue = parsedTransaction.type.rawValue
        self.categoryName = categoryName
        payee = parsedTransaction.payee
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try FinanceStore.addImportedTransaction(
                amountPaise: amountPaise,
                type: TransactionType(rawValue: transactionTypeRawValue) ?? .expense,
                categoryName: categoryName,
                payee: payee,
                note: "Imported from SMS"
            )
            return .result(dialog: "Saved \(MoneyFormatting.display(amountPaise)) for \(categoryName).")
        } catch ShortcutExpenseError.noActiveAccount {
            return .result(dialog: "Open moni and create an account first.")
        }
    }
}

private struct SMSCategoryReviewSnippet: View {
    let parsedTransaction: ParsedSMSTransaction

    var body: some View {
        VStack(spacing: 14) {
            SMSImportResultSnippet(
                title: "Choose category",
                subtitle: "\(MoneyFormatting.display(parsedTransaction.amountPaise)) • \(parsedTransaction.payee)",
                systemImageName: "text.bubble"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                ForEach(categoryNames, id: \.self) { categoryName in
                    Button(intent: SaveImportedSMSTransactionIntent(parsedTransaction: parsedTransaction, categoryName: categoryName)) {
                        categoryTile(categoryName)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var categoryNames: [String] {
        var names = FinanceStore.shortcutCategoryNames
        if let inferred = parsedTransaction.categoryName, !names.contains(inferred) {
            names.insert(inferred, at: 0)
        }
        if !names.contains("Uncategorized") {
            names.append("Uncategorized")
        }
        return names
    }

    private func categoryTile(_ categoryName: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: iconName(for: categoryName))
                .font(.title3.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(.primary.opacity(0.06), in: Circle())

            Text(categoryName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground).opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

private struct SMSImportResultSnippet: View {
    let title: String
    let subtitle: String
    let systemImageName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImageName)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.primary.opacity(0.07), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
