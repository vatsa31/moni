//
//  BottomActionBar.swift
//  moni
//

import SwiftUI

extension ContentView {
    var bottomActionBar: some View {
        HStack(spacing: 10) {
            tabBarButton(.home)

            quickExpenseButton

            tabBarButton(.history)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.moniSurface.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.moniInk.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: Color.moniInk.opacity(0.10), radius: 24, y: 12)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    func tabBarButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(Motion.snappy) {
                selectedTab = tab
            }
            triggerSelectionHaptic(strength: .medium)
        } label: {
            ZStack {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.moniLeaf.opacity(0.14))
                        .matchedGeometryEffect(id: "selectedTab", in: tabSelectionNamespace)
                }

                VStack(spacing: 4) {
                    Image(systemName: selectedTab == tab ? tab.filledIconName : tab.iconName)
                        .font(.title3.weight(.medium))
                        .symbolEffect(.bounce, value: selectedTab == tab)

                    Text(tab.label)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(selectedTab == tab ? Color.moniInk : Color.moniMuted)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(MicroPressButtonStyle())
    }

    var quickExpenseButton: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.medium))
            .foregroundStyle(Color.moniSurface)
            .frame(width: 62, height: 62)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.moniInk, Color.moniLeaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.36), lineWidth: 1)
                    }
            }
            .shadow(color: Color.moniLeaf.opacity(isChoosingQuickAmount ? 0.34 : 0.22), radius: isChoosingQuickAmount ? 24 : 14, y: isChoosingQuickAmount ? 12 : 7)
            .scaleEffect(isChoosingQuickAmount ? 1.12 : 1)
            .rotationEffect(.degrees(isChoosingQuickAmount ? 135 : 0))
            .offset(y: isChoosingQuickAmount ? -6 : 0)
            .accessibilityLabel("Add expense")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let upwardDrag = max(-value.translation.height, 0)
                        guard upwardDrag > 4 else { return }

                        isChoosingQuickAmount = true
                        let dragLimit = quickDragLimit
                        quickDragHeight = min(upwardDrag, dragLimit)
                        let nextAmountPaise = quickAmount(for: quickDragHeight, dragLimit: dragLimit)
                        if nextAmountPaise != quickAmountPaise {
                            triggerSelectionHaptic(strength: .strong)
                        }
                        triggerQuickDragHapticIfNeeded()
                        quickAmountPaise = nextAmountPaise
                    }
                    .onEnded { value in
                        let upwardDrag = max(-value.translation.height, 0)

                        if upwardDrag > 24, !quickExpenseCategories.isEmpty {
                            triggerImpactHaptic(strength: .heavy)
                            quickPickerAmountPaise = quickAmount(for: min(upwardDrag, quickDragLimit), dragLimit: quickDragLimit)
                            categoryDragOffset = .zero
                            highlightedQuickCategoryID = nil
                        } else {
                            activeSheet = .transaction(type: .expense, transaction: nil)
                        }

                        isChoosingQuickAmount = false
                        quickDragHeight = 0
                    }
            )
            .animation(Motion.bouncy, value: isChoosingQuickAmount)
    }
}
