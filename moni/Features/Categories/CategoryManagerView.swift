//
//  CategoryManagerView.swift
//  moni
//

import SwiftData
import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [SpendingCategory]
    @State private var newCategoryName = ""

    var body: some View {
        PaynoSheetScaffold(
            title: "Categories",
            subtitle: "Create and tune the categories used by quick expense.",
            primaryTitle: "Done",
            onPrimary: { dismiss() }
        ) {
            SectionPanel(title: "Add category", iconName: "plus") {
                HStack(spacing: 10) {
                    PaynoInputField(title: "Name", placeholder: "Category name", text: $newCategoryName)

                    VStack {
                        Spacer(minLength: 22)
                        Button {
                            addCategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(Color.moniLeaf)
                                .frame(width: 48, height: 48)
                                .background(Color.moniLeaf.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(MicroPressButtonStyle())
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            SectionPanel(title: "Categories", iconName: "tag") {
                if categories.isEmpty {
                    EmptyStatePanel(title: "No categories", subtitle: "Add a category to use quick expense.", iconName: "tag")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.element.persistentModelID) { index, category in
                            CategoryEditRow(category: category) {
                                deleteCategory(at: index)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addCategory() {
        FinanceCommands.addCategory(name: newCategoryName, in: modelContext)
        newCategoryName = ""
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }

    private func deleteCategory(at index: Int) {
        modelContext.delete(categories[index])
    }
}

struct CategoryEditRow: View {
    let category: SpendingCategory
    let onDelete: () -> Void
    @State private var name: String

    init(category: SpendingCategory, onDelete: @escaping () -> Void) {
        self.category = category
        self.onDelete = onDelete
        _name = State(initialValue: category.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            PaynoInputField(title: "Category", placeholder: "Category", text: $name)
                .onSubmit {
                    category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .onChange(of: name) {
                    category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.moniCoral)
                    .frame(width: 44, height: 44)
                    .background(Color.moniCoral.opacity(0.10), in: Circle())
            }
            .buttonStyle(MicroPressButtonStyle())
            .padding(.top, 22)
        }
    }
}
