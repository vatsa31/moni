//
//  HistoryView.swift
//  moni
//

import SwiftUI

extension ContentView {
    var history: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(spacing: 18) {
                    topControlStrip(title: "History", subtitle: "\(transactions.count) transactions")

                    SectionPanel(title: "All transactions", iconName: "clock") {
                        if transactions.isEmpty {
                            EmptyStatePanel(
                                title: "Nothing here yet",
                                subtitle: "Tap the center plus to add an expense.",
                                iconName: "clock"
                            )
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(transactions) { transaction in
                                    Button {
                                        withAnimation(Motion.snappy) {
                                            activeSheet = .transaction(type: transaction.type, transaction: transaction)
                                        }
                                    } label: {
                                        TransactionRowView(transaction: transaction)
                                    }
                                    .buttonStyle(MicroPressButtonStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation(Motion.snappy) {
                                                modelContext.delete(transaction)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 118)
            }
            .scrollIndicators(.hidden)
        }
    }
}
