import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.name) private var categories: [Category]
    @Binding var selectedCategoryName: String?

    @State private var showNewCategoryAlert = false
    @State private var newCategoryInput = ""

    var body: some View {
        NavigationStack {
            List {
                // None option
                Button {
                    selectedCategoryName = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Geen categorie")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if selectedCategoryName == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Existing categories
                if !categories.isEmpty {
                    Section {
                        ForEach(categories) { category in
                            Button {
                                selectedCategoryName = category.name
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundStyle(.blue.opacity(0.7))
                                        .frame(width: 24)
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategoryName == category.name {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                // Clear actions that use this category name
                                let deletedName = categories[index].name
                                if selectedCategoryName == deletedName {
                                    selectedCategoryName = nil
                                }
                                modelContext.delete(categories[index])
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .navigationTitle("Categorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newCategoryInput = ""
                        showNewCategoryAlert = true
                    } label: {
                        Label("Nieuwe categorie", systemImage: "plus")
                    }
                }
            }
            .alert("Nieuwe categorie", isPresented: $showNewCategoryAlert) {
                TextField("Naam", text: $newCategoryInput)
                    .autocorrectionDisabled()
                Button("Voeg toe") {
                    addCategory()
                }
                Button("Annuleer", role: .cancel) {
                    newCategoryInput = ""
                }
            } message: {
                Text("Voer een naam in voor de nieuwe categorie.")
            }
        }
    }

    private func addCategory() {
        let trimmed = newCategoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Avoid duplicates (case-insensitive)
        let exists = categories.contains { $0.name.lowercased() == trimmed.lowercased() }
        if !exists {
            modelContext.insert(Category(name: trimmed))
            try? modelContext.save()
        }

        // Select the (new or existing) category
        let matchingName = categories.first { $0.name.lowercased() == trimmed.lowercased() }?.name ?? trimmed
        selectedCategoryName = matchingName
        newCategoryInput = ""
        dismiss()
    }
}
