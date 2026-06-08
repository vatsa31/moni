//
//  PaynoDesignSystem.swift
//  moni
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.moniCanvas,
                    Color.moniMist,
                    Color(red: 0.94, green: 0.97, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.moniLeaf.opacity(0.22), .clear],
                center: UnitPoint(x: 0.18, y: 0.12),
                startRadius: 10,
                endRadius: 390
            )

            RadialGradient(
                colors: [Color.moniSky.opacity(0.20), .clear],
                center: UnitPoint(x: 0.76, y: 0.32),
                startRadius: 18,
                endRadius: 360
            )

            RadialGradient(
                colors: [Color.moniLime.opacity(0.24), .clear],
                center: UnitPoint(x: 0.42, y: 0.92),
                startRadius: 8,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct SectionPanel<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.moniLeaf)
                    .frame(width: 30, height: 30)
                    .background(Color.moniLeaf.opacity(0.10), in: Circle())

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)

                Spacer()
            }

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.moniSurface.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
                }
        }
        .shadow(color: Color.moniInk.opacity(0.08), radius: 24, y: 14)
    }
}

struct EmptyStatePanel: View {
    let title: String
    let subtitle: String
    let iconName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.moniLeaf)
                .frame(width: 44, height: 44)
                .background(Color.moniLeaf.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moniInk)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.moniMuted)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.moniMist.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct BudgetHeroCard: View {
    let monthlySpentPaise: Int
    let totalBudgetPaise: Int?
    let budgetProgress: Double
    let budgetState: BudgetColorState
    let isVisible: Bool
    let onBudgetTap: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                Spacer(minLength: 44)
                VStack(spacing: 6) {
                    Text("This month")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.moniMuted)
                    Text(MoneyFormatting.display(monthlySpentPaise))
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.moniInk)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                    Text("spent")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.moniMuted)
                }
                .frame(maxWidth: .infinity)

                Button(action: onBudgetTap) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.moniInk)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.62), in: Circle())
                }
                .buttonStyle(MicroPressButtonStyle())
                .accessibilityLabel("Edit budget")
            }

            if let totalBudgetPaise {
                AnimatedProgressBar(progress: budgetProgress, state: budgetState)

                HStack {
                    Text("\(MoneyFormatting.display(max(totalBudgetPaise - monthlySpentPaise, 0))) left")
                    Spacer()
                    Text("Budget \(MoneyFormatting.display(totalBudgetPaise))")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.moniMuted)
                .contentTransition(.numericText())
            } else {
                Text("Set a monthly budget to grade spending.")
                    .font(.footnote)
                    .foregroundStyle(Color.moniMuted)
            }
        }
        .padding(22)
        .background {
            AnimatedBudgetBackdrop(progress: budgetProgress, state: budgetState)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: ambientShadowColor, radius: isVisible ? 32 : 8, y: isVisible ? 16 : 2)
        .scaleEffect(isVisible ? 1 : 0.96)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 16)
    }

    private var ambientShadowColor: Color {
        switch budgetState {
        case .neutral:
            Color.moniInk.opacity(0.12)
        case .green:
            Color.moniLeaf.opacity(0.20)
        case .yellow:
            Color.moniAmber.opacity(0.22)
        case .red:
            Color.moniCoral.opacity(0.22)
        }
    }
}

struct AnimatedBudgetBackdrop: View {
    let progress: Double
    let state: BudgetColorState

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18 + min(progress, 1) * 0.08),
                    Color.clear,
                    Color.moniInk.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
        }
    }

    private var colors: [Color] {
        switch state {
        case .neutral:
            [Color.white, Color.moniMist, Color.moniSky.opacity(0.18)]
        case .green:
            progress < 0.5
                ? [Color.white, Color.moniLime.opacity(0.72), Color.moniSky.opacity(0.18)]
                : [Color.white, Color.moniLeaf.opacity(0.30), Color.moniLime.opacity(0.56)]
        case .yellow:
            [Color.white, Color.moniAmber.opacity(0.42), Color.moniLime.opacity(0.26)]
        case .red:
            [Color.white, Color.moniCoral.opacity(0.26), Color.moniAmber.opacity(0.22)]
        }
    }
}

struct AnimatedProgressBar: View {
    let progress: Double
    let state: BudgetColorState

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.moniInk.opacity(0.08))

                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * clamped)
                    .animation(Motion.snappy, value: clamped)
            }
        }
        .frame(height: 9)
    }

    private var color: Color {
        switch state {
        case .neutral:
            Color.moniInk.opacity(0.54)
        case .green:
            Color.moniLeaf
        case .yellow:
            Color.moniAmber
        case .red:
            Color.moniCoral
        }
    }
}

extension View {
    func motionRow(index: Int, isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(Motion.entrance.delay(Double(index) * 0.035), value: isVisible)
    }
}

struct MicroPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}

enum Motion {
    static let micro = Animation.spring(response: 0.16, dampingFraction: 0.74)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.34, dampingFraction: 0.68)
    static let entrance = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

struct PaynoSheetScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let primaryTitle: String?
    let primaryDisabled: Bool
    let onCancel: (() -> Void)?
    let onPrimary: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        primaryTitle: String? = nil,
        primaryDisabled: Bool = false,
        onCancel: (() -> Void)? = nil,
        onPrimary: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.primaryDisabled = primaryDisabled
        self.onCancel = onCancel
        self.onPrimary = onPrimary
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.moniInk)

                            if let subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.moniMuted)
                            }
                        }

                        Spacer()

                        if let onCancel {
                            Button(action: onCancel) {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.moniInk)
                                    .frame(width: 38, height: 38)
                                    .background(Color.moniSurface, in: Circle())
                                    .shadow(color: Color.moniInk.opacity(0.08), radius: 12, y: 6)
                            }
                            .buttonStyle(MicroPressButtonStyle())
                            .accessibilityLabel("Cancel")
                        }
                    }

                    content

                    if let primaryTitle, let onPrimary {
                        Button(primaryTitle, action: onPrimary)
                            .buttonStyle(PaynoPrimaryButtonStyle())
                            .disabled(primaryDisabled)
                            .opacity(primaryDisabled ? 0.45 : 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct PaynoInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.moniMuted)

            TextField(placeholder, text: $text, axis: axis)
                .font(.body)
                .foregroundStyle(Color.moniInk)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.moniMist.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
                }
        }
    }
}

struct PaynoOptionRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.moniMuted)

            Spacer()

            content
                .font(.body)
                .foregroundStyle(Color.moniInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.moniMist.opacity(0.70), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.moniInk.opacity(0.05), lineWidth: 1)
        }
    }
}

struct PaynoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.moniSurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.moniInk, Color.moniLeaf],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color.moniLeaf.opacity(configuration.isPressed ? 0.12 : 0.22), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}

struct PaynoDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.moniCoral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.moniCoral.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.micro, value: configuration.isPressed)
    }
}
