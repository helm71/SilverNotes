import SwiftUI
import SwiftData

struct ActionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let action: Action

    @State private var editedTitle: String
    @State private var editedDetail: String
    @State private var editedDueDate: Date
    @State private var hasDueDate: Bool
    @State private var editedCategoryName: String?
    @State private var showDeleteConfirm = false
    @State private var showCategoryPicker = false

    init(action: Action) {
        self.action = action
        _editedTitle = State(initialValue: action.title)
        _editedDetail = State(initialValue: action.detail ?? "")
        _editedDueDate = State(initialValue: action.dueDate ?? Date())
        _hasDueDate = State(initialValue: action.dueDate != nil)
        _editedCategoryName = State(initialValue: action.categoryName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Actie") {
                    TextField("Titel", text: $editedTitle)
                    TextField("Details (optioneel)", text: $editedDetail, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Categorie") {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            Label("Categorie", systemImage: "tag")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let name = editedCategoryName {
                                Text(name)
                                    .foregroundStyle(.blue)
                            } else {
                                Text("Geen")
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Status") {
                    ForEach(ActionStatus.allCases) { status in
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 10, height: 10)
                            Text(status.displayName)
                            Spacer()
                            if action.status == status {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                action.status = status
                                if status == .closed {
                                    NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
                                }
                            }
                            try? modelContext.save()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }

                Section("Tijdstip") {
                    Toggle("Heeft tijdstip", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Datum & tijd", selection: $editedDueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Verwijder actie", systemImage: "trash")
                            Spacer()
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aangemaakt: \(action.createdAt.formatted(date: .long, time: .shortened))")
                        if let sourceId = action.sourceNoteId {
                            Text("Notitie ID: \(sourceId.uuidString.prefix(8))...")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Actie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Verwijder actie?", isPresented: $showDeleteConfirm) {
                Button("Verwijder", role: .destructive) {
                    NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
                    modelContext.delete(action)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Annuleer", role: .cancel) {}
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(selectedCategoryName: $editedCategoryName)
            }
        }
    }

    private func saveChanges() {
        action.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        action.detail = editedDetail.isEmpty ? nil : editedDetail
        action.dueDate = hasDueDate ? editedDueDate : nil
        action.categoryName = editedCategoryName

        // Reschedule notification if due date changed
        NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
        if hasDueDate && action.status != .closed {
            NotificationService.shared.scheduleNotification(for: action)
        }

        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
