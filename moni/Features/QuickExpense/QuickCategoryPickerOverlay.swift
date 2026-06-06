//
//  QuickCategoryPickerOverlay.swift
//  moni
//

import SwiftData
import SwiftUI

struct QuickCategoryPickerOverlay: View {
    let amountPaise: Int
    let categories: [SpendingCategory]
    let highlightedCategoryID: PersistentIdentifier?
    @Binding var dragOffset: CGSize
    let onDragChanged: (CGPoint, [PersistentIdentifier: CGPoint]) -> Void
    let onDrop: (CGPoint, [PersistentIdentifier: CGPoint]) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let centers = categoryCenters(in: size)
            let amountPoint = CGPoint(
                x: center.x + dragOffset.width,
                y: center.y + dragOffset.height
            )
            let ringSize = min(size.width * 0.86, size.height * 0.54, 360)
            let sectorCount = max(categories.count, 1)

            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)

                ZStack {
                    ForEach(categories.indices, id: \.self) { index in
                        let category = categories[index]
                        let isHighlighted = highlightedCategoryID == category.persistentModelID
                        let startAngle = Angle.degrees(-90 + Double(index) * 360 / Double(sectorCount))
                        let endAngle = Angle.degrees(-90 + Double(index + 1) * 360 / Double(sectorCount))

                        AnnularSector(startAngle: startAngle, endAngle: endAngle, innerRadiusRatio: 0.44)
                            .fill(sectorFillColor(isHighlighted: isHighlighted))
                            .overlay {
                                AnnularSector(startAngle: startAngle, endAngle: endAngle, innerRadiusRatio: 0.44)
                                    .stroke(Color.moniInk.opacity(0.08), lineWidth: 1)
                            }
                            .animation(.easeOut(duration: 0.14), value: isHighlighted)

                        if let iconPoint = centers[category.persistentModelID] {
                            Image(systemName: categoryIconName(for: category))
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color.moniInk)
                                .frame(width: 46, height: 46)
                                .background(isHighlighted ? Color.moniLime : Color.moniSurface, in: Circle())
                                .scaleEffect(isHighlighted ? 1.12 : 1)
                                .position(
                                    x: iconPoint.x - center.x + ringSize / 2,
                                    y: iconPoint.y - center.y + ringSize / 2
                                )
                        }
                    }

                    Circle()
                        .fill(Color.moniSurface.opacity(0.96))
                        .frame(width: ringSize * 0.44, height: ringSize * 0.44)
                        .overlay {
                            Circle()
                                .stroke(Color.moniInk.opacity(0.08), lineWidth: 1)
                        }
                }
                .frame(width: ringSize, height: ringSize)
                .shadow(color: Color.moniInk.opacity(0.12), radius: 28, y: 14)
                .position(center)

                Text(MoneyFormatting.display(amountPaise))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.moniInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .position(amountPoint)
                    .gesture(
                        DragGesture(coordinateSpace: .named("quickCategoryPicker"))
                            .onChanged { value in
                                dragOffset = value.translation
                                onDragChanged(value.location, centers)
                            }
                            .onEnded { value in
                                onDrop(value.location, centers)
                            }
                    )
            }
            .coordinateSpace(name: "quickCategoryPicker")
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func categoryCenters(in size: CGSize) -> [PersistentIdentifier: CGPoint] {
        guard !categories.isEmpty else { return [:] }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringSize = min(size.width * 0.86, size.height * 0.54, 360)
        let radius = ringSize * 0.35
        let startAngle = -Double.pi / 2
        let angleStep = (Double.pi * 2) / Double(categories.count)

        return Dictionary(
            uniqueKeysWithValues: categories.enumerated().map { index, category in
                let angle = startAngle + angleStep * (Double(index) + 0.5)
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                return (category.persistentModelID, point)
            }
        )
    }

    private func sectorFillColor(isHighlighted: Bool) -> Color {
        isHighlighted ? Color.moniLime.opacity(0.55) : Color.moniSurface.opacity(0.72)
    }

    private func categoryIconName(for category: SpendingCategory) -> String {
        let name = category.name.lowercased()

        if name.contains("food") || name.contains("restaurant") {
            return "fork.knife"
        }
        if name.contains("grocer") {
            return "basket"
        }
        if name.contains("transport") || name.contains("travel") {
            return "car"
        }
        if name.contains("shop") {
            return "bag"
        }
        if name.contains("bill") {
            return "doc.text"
        }
        if name.contains("health") {
            return "cross.case"
        }
        if name.contains("entertain") {
            return "popcorn"
        }

        return "tag"
    }
}

struct AnnularSector: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio

        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
