//
//  ThemeBuilderView.swift
//  moni
//

import SwiftUI

struct ThemeBuilderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ThemeStorageKey.useCustomTheme) private var useCustomTheme = false
    @AppStorage(ThemeStorageKey.customThemeJSON) private var customThemeJSON = ""

    @State private var draftTheme: AppColorTheme
    @State private var draftUseCustomTheme: Bool

    init() {
        let storedTheme = AppColorTheme.decoded(
            from: UserDefaults.standard.string(forKey: ThemeStorageKey.customThemeJSON) ?? ""
        )
        _draftTheme = State(initialValue: storedTheme ?? AppColorTheme.current)
        _draftUseCustomTheme = State(initialValue: UserDefaults.standard.bool(forKey: ThemeStorageKey.useCustomTheme))
    }

    var body: some View {
        PaynoSheetScaffold(
            title: "Theme builder",
            subtitle: "Tune the app palette and keep the current design as the default.",
            primaryTitle: "Done",
            onCancel: { dismiss() },
            onPrimary: save
        ) {
            SectionPanel(title: "Mode", iconName: "paintpalette") {
                Toggle(isOn: $draftUseCustomTheme.animation(Motion.snappy)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use custom theme")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.moniInk)
                        Text("Turn this off to use the default light and dark palettes.")
                            .font(.caption)
                            .foregroundStyle(Color.moniMuted)
                    }
                }
                .tint(Color.moniLeaf)
            }

            SectionPanel(title: "Preview", iconName: "sparkles") {
                ThemePreview(theme: draftTheme)
            }

            SectionPanel(title: "Base colors", iconName: "circle.hexagongrid") {
                VStack(spacing: 10) {
                    ThemeColorRow(title: "Canvas", color: colorBinding(\.canvasHex))
                    ThemeColorRow(title: "Surface", color: colorBinding(\.surfaceHex))
                    ThemeColorRow(title: "Soft fill", color: colorBinding(\.mistHex))
                    ThemeColorRow(title: "Text", color: colorBinding(\.inkHex))
                    ThemeColorRow(title: "Muted text", color: colorBinding(\.mutedHex))
                }
            }

            SectionPanel(title: "Accents", iconName: "swatchpalette") {
                VStack(spacing: 10) {
                    ThemeColorRow(title: "Primary", color: colorBinding(\.leafHex))
                    ThemeColorRow(title: "Glow", color: colorBinding(\.limeHex))
                    ThemeColorRow(title: "Cool accent", color: colorBinding(\.skyHex))
                    ThemeColorRow(title: "Warning", color: colorBinding(\.amberHex))
                    ThemeColorRow(title: "Negative", color: colorBinding(\.coralHex))
                }
            }

            Button {
                withAnimation(Motion.snappy) {
                    draftTheme = AppColorTheme.defaultTheme(for: colorScheme)
                }
            } label: {
                Label("Reset to default palette", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PaynoDestructiveButtonStyle())
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<AppColorTheme, String>) -> Binding<Color> {
        Binding(
            get: {
                Color(hex: draftTheme[keyPath: keyPath])
            },
            set: { newColor in
                #if canImport(UIKit)
                draftTheme[keyPath: keyPath] = newColor.hexString ?? draftTheme[keyPath: keyPath]
                #endif
            }
        )
    }

    private func save() {
        useCustomTheme = draftUseCustomTheme
        customThemeJSON = draftTheme.encoded()
        dismiss()
    }
}

private struct ThemeColorRow: View {
    let title: String
    @Binding var color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.moniInk.opacity(0.10), lineWidth: 1)
                }

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.moniInk)

            Spacer()

            ColorPicker(title, selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.moniMist.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ThemePreview: View {
    let theme: AppColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("June spending")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.muted)
                    Text("₹18,420")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.ink)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.ink)
                    .frame(width: 38, height: 38)
                    .background(theme.surface.opacity(0.72), in: Circle())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.ink.opacity(0.08))
                    Capsule()
                        .fill(theme.leaf)
                        .frame(width: proxy.size.width * 0.62)
                }
            }
            .frame(height: 9)

            HStack(spacing: 10) {
                previewChip("Food", color: theme.lime)
                previewChip("Travel", color: theme.sky)
                previewChip("Bills", color: theme.amber)
            }
        }
        .padding(18)
        .background {
            LinearGradient(
                colors: [theme.surface, theme.mist, theme.sky.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.ink.opacity(0.06), lineWidth: 1)
        }
    }

    private func previewChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.35), in: Capsule())
    }
}
