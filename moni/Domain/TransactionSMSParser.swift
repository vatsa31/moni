//
//  TransactionSMSParser.swift
//  moni
//

import Foundation

struct ParsedSMSTransaction {
    let amountPaise: Int
    let type: TransactionType
    let payee: String
    let categoryName: String?
    let sourceText: String
}

enum TransactionSMSParser {
    static func parse(_ text: String) -> ParsedSMSTransaction? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amountPaise = parseAmountPaise(from: cleanedText),
              let type = parseType(from: cleanedText) else {
            return nil
        }

        let payee = parsePayee(from: cleanedText, type: type)
        let categoryName = type == .expense ? inferCategory(from: cleanedText, payee: payee) : nil

        return ParsedSMSTransaction(
            amountPaise: amountPaise,
            type: type,
            payee: payee,
            categoryName: categoryName,
            sourceText: cleanedText
        )
    }

    private static func parseType(from text: String) -> TransactionType? {
        let lowercased = text.lowercased()

        let debitWords = ["debited", "debit", "spent", "paid", "purchase", "withdrawn", "withdrawal", "charged"]
        if debitWords.contains(where: lowercased.contains) {
            return .expense
        }

        let creditWords = ["credited", "credit", "received", "deposited", "refund", "cashback"]
        if creditWords.contains(where: lowercased.contains) {
            return .income
        }

        return nil
    }

    private static func parseAmountPaise(from text: String) -> Int? {
        let patterns = [
            #"(?i)(?:inr|rs\.?|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|₹)"#,
            #"(?i)\b(?:debited|debit|credited|credit|paid|spent|received|withdrawn|charged)\s+(?:by|with|for|of)?\s*(?:inr|rs\.?|₹)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)\b(?:amount|amt)\s*(?:of|is|:|-)?\s*(?:inr|rs\.?|₹)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern: pattern, in: text),
                  let range = Range(match.range(at: 1), in: text) else {
                continue
            }

            let amountText = String(text[range]).replacingOccurrences(of: ",", with: "")
            if let amount = Double(amountText), amount > 0 {
                return Int((amount * 100).rounded())
            }
        }

        return nil
    }

    private static func parsePayee(from text: String, type: TransactionType) -> String {
        let lowercased = text.lowercased()
        let patterns: [String]

        if type == .income {
            patterns = [
                #"(?i)\b(?:from|trf from|transfer from)\s+([a-z0-9 &._-]{2,48})"#,
                #"(?i)\bby\s+([a-z0-9 &._-]{2,48})"#
            ]
        } else {
            patterns = [
                #"(?i)\b(?:trf to|transfer to|paid to|to|towards|at)\s+([a-z0-9 &._-]{2,48})"#,
                #"(?i)\bmerchant\s+([a-z0-9 &._-]{2,48})"#
            ]
        }

        for pattern in patterns {
            guard let match = firstMatch(pattern: pattern, in: text),
                  let range = Range(match.range(at: 1), in: text) else {
                continue
            }

            let candidate = trimPayee(String(text[range]))
            if !candidate.isEmpty {
                return candidate
            }
        }

        if lowercased.contains("upi") {
            return "UPI"
        }

        if lowercased.contains("atm") {
            return "ATM"
        }

        return type == .income ? "SMS credit" : "SMS debit"
    }

    private static func trimPayee(_ value: String) -> String {
        let stopWords = [
            " refno",
            " ref no",
            " ref",
            " txn",
            " transaction",
            " on date",
            " on ",
            " using",
            " with",
            " from",
            " at ",
            " if not",
            ". ",
            ","
        ]
        var result = value

        for stopWord in stopWords {
            if let range = result.range(of: stopWord, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }

        return result
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,-\n\t"))
            .capitalized
    }

    private static func inferCategory(from text: String, payee: String) -> String? {
        let searchable = "\(text) \(payee)".lowercased()

        let rules: [(String, [String])] = [
            ("Food", ["swiggy", "zomato", "restaurant", "cafe", "coffee", "food", "dining"]),
            ("Groceries", ["grocery", "groceries", "dmart", "bigbasket", "blinkit", "zepto", "reliance fresh"]),
            ("Transport", ["uber", "ola", "metro", "fuel", "petrol", "diesel", "parking", "irctc"]),
            ("Shopping", ["amazon", "flipkart", "myntra", "ajio", "nykaa", "shopping", "store"]),
            ("Bills", ["bill", "electricity", "airtel", "jio", "vi ", "broadband", "recharge", "insurance"]),
            ("Health", ["pharmacy", "hospital", "clinic", "medical", "apollo", "pharmeasy"]),
            ("Entertainment", ["netflix", "prime", "hotstar", "bookmyshow", "spotify", "movie"]),
            ("Travel", ["flight", "hotel", "makemytrip", "goibibo", "airbnb", "train"])
        ]

        return rules.first { _, keywords in
            keywords.contains(where: searchable.contains)
        }?.0
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range)
    }
}
