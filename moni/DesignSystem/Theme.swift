//
//  Theme.swift
//  moni
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ThemeStorageKey {
    static let useCustomTheme = "useCustomTheme"
    static let customThemeJSON = "customThemeJSON"
}

struct AppColorTheme: Codable, Equatable {
    var canvasHex: String
    var surfaceHex: String
    var mistHex: String
    var inkHex: String
    var mutedHex: String
    var leafHex: String
    var limeHex: String
    var skyHex: String
    var amberHex: String
    var coralHex: String

    static let defaultLight = AppColorTheme(
        canvasHex: "#F4F6EE",
        surfaceHex: "#FEFEFA",
        mistHex: "#E8F0E6",
        inkHex: "#121816",
        mutedHex: "#69746B",
        leafHex: "#41A750",
        limeHex: "#C4EC5D",
        skyHex: "#A6D5EB",
        amberHex: "#EFA535",
        coralHex: "#E65045"
    )

    static let defaultDark = AppColorTheme(
        canvasHex: "#0E1311",
        surfaceHex: "#171E1A",
        mistHex: "#222B25",
        inkHex: "#F2F6EF",
        mutedHex: "#A6B2A8",
        leafHex: "#79D46F",
        limeHex: "#BDE85D",
        skyHex: "#75B8D9",
        amberHex: "#E7AF4A",
        coralHex: "#E76B62"
    )

    static func defaultTheme(for colorScheme: ColorScheme) -> AppColorTheme {
        colorScheme == .dark ? .defaultDark : .defaultLight
    }

    static func decoded(from json: String) -> AppColorTheme? {
        guard let data = json.data(using: .utf8), !json.isEmpty else {
            return nil
        }
        return try? JSONDecoder().decode(AppColorTheme.self, from: data)
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    var canvas: Color { Color(hex: canvasHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var mist: Color { Color(hex: mistHex) }
    var ink: Color { Color(hex: inkHex) }
    var muted: Color { Color(hex: mutedHex) }
    var leaf: Color { Color(hex: leafHex) }
    var lime: Color { Color(hex: limeHex) }
    var sky: Color { Color(hex: skyHex) }
    var amber: Color { Color(hex: amberHex) }
    var coral: Color { Color(hex: coralHex) }
}

extension AppColorTheme {
    static var current: AppColorTheme {
        if UserDefaults.standard.bool(forKey: ThemeStorageKey.useCustomTheme),
           let customTheme = AppColorTheme.decoded(from: UserDefaults.standard.string(forKey: ThemeStorageKey.customThemeJSON) ?? "") {
            return customTheme
        }

        #if canImport(UIKit)
        return defaultTheme(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        #else
        return defaultLight
        #endif
    }
}

extension Color {
    static var moniCanvas: Color { AppColorTheme.current.canvas }
    static var moniSurface: Color { AppColorTheme.current.surface }
    static var moniMist: Color { AppColorTheme.current.mist }
    static var moniInk: Color { AppColorTheme.current.ink }
    static var moniMuted: Color { AppColorTheme.current.muted }
    static var moniLeaf: Color { AppColorTheme.current.leaf }
    static var moniLime: Color { AppColorTheme.current.lime }
    static var moniSky: Color { AppColorTheme.current.sky }
    static var moniAmber: Color { AppColorTheme.current.amber }
    static var moniCoral: Color { AppColorTheme.current.coral }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15
            green = Double((value >> 4) & 0xF) / 15
            blue = Double(value & 0xF) / 15
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = Double((value >> 24) & 0xFF) / 255
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    #if canImport(UIKit)
    var hexString: String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
    #endif
}
