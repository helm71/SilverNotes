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
    @State private var showDeleteConfirm = false

    init(action: Action) {
        self.action = action
        _editedTitle = State(initialValue: action.title)
        _editedDetail = State(initialValue: action.detail ?? "")
        _editedDueDate = State(initialValue: action.dueDate ?? Date())
        _hasDueDate = State(initialValue: action.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Actie") {
                    TextField("Titel", text: $editedTitle)
                    TextField("Details (optioneel)", text: $editedDetail, axis: .vertical)
                        .lineLimit(3...6)
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
        }
    }

    private func saveChanges() {
        action.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        action.detail = editedDetail.isEmpty ? nil : editedDetail
        action.dueDate = hasDueDate ? editedDueDate : nil

        // Reschedule notification if due date changed
        NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
        if hasDueDate && action.status != .closed {
            NotificationService.shared.scheduleNotification(for: action)
        }

        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
