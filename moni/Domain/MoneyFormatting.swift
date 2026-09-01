//
//  MoneyFormatting.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import Foundation

/// Helpers for precise INR <-> paise conversions and display.
enum MoneyFormatting {
    static let rupees: FloatingPointFormatStyle<Double>.Currency = .currency(code: "INR")
        .precision(.fractionLength(0...2))

    static func paise(from rupeesText: String) -> Int {
        let cleaned = rupeesText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Decimal(string: cleaned), value >= 0 else {
            return 0
        }

        let paise = value * Decimal(100)
        return NSDecimalNumber(decimal: paise).rounding(accordingToBehavior: nil).intValue
    }

    static func rupeesText(fromPaise paise: Int) -> String {
        let rupees = Decimal(paise) / Decimal(100)
        return NSDecimalNumber(decimal: rupees).stringValue
    }

    static func display(_ paise: Int) -> String {
        (Double(paise) / 100).formatted(rupees)
    }
}

