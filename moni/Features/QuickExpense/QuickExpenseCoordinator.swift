//
//  QuickExpenseCoordinator.swift
//  moni
//

import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension ContentView {
    var backgroundBlurRadius: CGFloat {
        if quickPickerAmountPaise != nil {
            return 10
        }

        return isChoosingQuickAmount ? min(quickDragHeight / 44, 10) : 0
    }

    @ViewBuilder
    var quickExpenseOverlay: some View {
        if isChoosingQuickAmount {
            quickAmountScrubberOverlay
        }

        if let amountPaise = quickPickerAmountPaise {
            QuickCategoryPickerOverlay(
                amountPaise: amountPaise,
                categories: quickExpenseCategories,
                highlightedCategoryID: highlightedQuickCategoryID,
                dragOffset: $categoryDragOffset,
                onDragChanged: { dragLocation, categoryCenters in
                    let nextCategoryID = closestCategoryID(
                        to: dragLocation,
                        in: categoryCenters,
                        maximumDistance: 86
                    )
                    if nextCategoryID != highlightedQuickCategoryID {
                        triggerSelectionHaptic(strength: .strong)
                    }
                    triggerCategoryDragHapticIfNeeded()
                    highlightedQuickCategoryID = nextCategoryID
                },
                onDrop: { dragLocation, categoryCenters in
                    if let categoryID = closestCategoryID(to: dragLocation, in: categoryCenters, maximumDistance: 96),
                       let category = categories.first(where: { $0.persistentModelID == categoryID }) {
                        triggerImpactHaptic(strength: .heavy)
                        saveQuickExpense(amountPaise: amountPaise, category: category)
                    }

                    withAnimation(.easeOut(duration: 0.26)) {
                        quickPickerAmountPaise = nil
                        categoryDragOffset = .zero
                        highlightedQuickCategoryID = nil
                    }
                },
                onCancel: {
                    withAnimation(.easeOut(duration: 0.22)) {
                        quickPickerAmountPaise = nil
                        categoryDragOffset = .zero
                        highlightedQuickCategoryID = nil
                    }
                }
            )
        }
    }

    var quickAmountScrubberOverlay: some View {
        ZStack {
            Color.black.opacity(min(0.08 + quickDragHeight / quickDragLimit * 0.22, 0.30))
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Text(MoneyFormatting.display(quickAmountPaise))
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(Color.moniInk)
                        .contentTransition(.numericText())

                    VStack(spacing: 8) {
                        ForEach(quickExpenseLadder.reversed(), id: \.self) { amount in
                            HStack(spacing: 8) {
                                Capsule()
                                    .fill(amount * 100 <= quickAmountPaise ? Color.moniLeaf : Color.moniMuted.opacity(0.24))
                                    .frame(width: amount == selectedQuickAmountRupees ? 34 : 16, height: 5)

                                if amount == selectedQuickAmountRupees {
                                    Text(MoneyFormatting.display(amount * 100))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.moniMuted)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .shadow(color: Color.moniInk.opacity(0.12), radius: 18, y: 8)
                .padding(.bottom, 84 + quickDragHeight * 0.58)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    var quickExpenseCategories: [SpendingCategory] {
        Array(categories.prefix(5))
    }

    var selectedQuickAmountRupees: Int {
        quickAmountPaise / 100
    }

    var quickDragLimit: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.bounds.height * 0.75
        #else
        620
        #endif
    }

    func quickAmount(for upwardDrag: CGFloat, dragLimit: CGFloat) -> Int {
        guard !quickExpenseLadder.isEmpty else { return 1_000 }

        let progress = min(max(Double(upwardDrag / max(dragLimit, 1)), 0), 1)
        let easedProgress = pow(progress, 1.35)
        let index = min(
            Int((easedProgress * Double(quickExpenseLadder.count - 1)).rounded()),
            quickExpenseLadder.count - 1
        )

        return quickExpenseLadder[index] * 100
    }

    func triggerSelectionHaptic(strength: HapticStrength = .medium) {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        UIImpactFeedbackGenerator(style: strength.impactStyle).impactOccurred(intensity: strength.intensity)
        #endif
    }

    func triggerImpactHaptic(strength: HapticStrength = .medium) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strength.impactStyle).impactOccurred(intensity: strength.intensity)
        #endif
    }

    func triggerQuickDragHapticIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastQuickDragHapticTime >= dragHapticInterval else { return }

        lastQuickDragHapticTime = now
        triggerImpactHaptic(strength: .medium)
    }

    func triggerCategoryDragHapticIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastCategoryDragHapticTime >= dragHapticInterval else { return }

        lastCategoryDragHapticTime = now
        triggerImpactHaptic(strength: .medium)
    }

    func closestCategoryID(
        to point: CGPoint,
        in categoryCenters: [PersistentIdentifier: CGPoint],
        maximumDistance: CGFloat
    ) -> PersistentIdentifier? {
        categoryCenters
            .map { id, center in
                (id: id, distance: hypot(point.x - center.x, point.y - center.y))
            }
            .filter { $0.distance <= maximumDistance }
            .min { $0.distance < $1.distance }?
            .id
    }

    func saveQuickExpense(amountPaise: Int, category: SpendingCategory) {
        guard let account = activeAccounts.first else { return }

        FinanceCommands.saveQuickExpense(amountPaise: amountPaise, category: category, account: account, in: modelContext)
        selectedTab = .home
    }

    func presentPendingBackTapExpenseIfNeeded() {
        guard quickPickerAmountPaise == nil, !activeAccounts.isEmpty, !quickExpenseCategories.isEmpty else { return }
        guard let amountPaise = FinanceStore.consumePendingBackTapExpensePaise() else { return }

        selectedTab = .home
        quickAmountPaise = amountPaise
        categoryDragOffset = .zero
        highlightedQuickCategoryID = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            quickPickerAmountPaise = amountPaise
        }
    }
}
