//
//  AppState.swift
//  moni
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTab {
    case home
    case history

    var title: String {
        switch self {
        case .home:
            ""
        case .history:
            "History"
        }
    }

    var label: String {
        switch self {
        case .home:
            "Home"
        case .history:
            "History"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            "house"
        case .history:
            "clock"
        }
    }

    var filledIconName: String {
        switch self {
        case .home:
            "house.fill"
        case .history:
            "clock.fill"
        }
    }
}

enum HapticStrength {
    case medium
    case strong
    case heavy

    #if canImport(UIKit)
    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .medium:
            .medium
        case .strong:
            .rigid
        case .heavy:
            .heavy
        }
    }

    var intensity: CGFloat {
        switch self {
        case .medium:
            0.72
        case .strong:
            0.9
        case .heavy:
            1
        }
    }
    #endif
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum ActiveSheet: Identifiable {
    case transaction(type: TransactionType, transaction: MoneyTransaction?)
    case account(Account?)
    case budget
    case categories
    case themeBuilder

    var id: String {
        switch self {
        case let .transaction(type, transaction):
            "transaction-\(type.rawValue)-\(transaction?.persistentModelID.hashValue ?? 0)"
        case let .account(account):
            "account-\(account?.persistentModelID.hashValue ?? 0)"
        case .budget:
            "budget"
        case .categories:
            "categories"
        case .themeBuilder:
            "themeBuilder"
        }
    }
}
