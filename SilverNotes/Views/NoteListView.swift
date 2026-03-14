import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var showNewNote = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedNotes = Set<Note.ID>()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    emptyStateView
                } else {
                    noteListContent
                }
            }
            .navigationTitle("Notities")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !notes.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if editMode == .active && !selectedNotes.isEmpty {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Verwijder", systemImage: "trash")
                        }
                    }
                    Button {
                        showNewNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showNewNote) {
                NoteEditorView()
            }
            .onAppear {
                NotificationService.shared.updateBadge(count: notes.count)
            }
            .onChange(of: notes.count) { _, newCount in
                NotificationService.shared.updateBadge(count: newCount)
            }
            .confirmationDialog("Verwijder \(selectedNotes.count) notitie(s)?", isPresented: $showDeleteConfirm) {
                Button("Verwijder", role: .destructive) { deleteSelected() }
                Button("Annuleer", role: .cancel) {}
            }
        }
    }

    private var noteListContent: some View {
        List(selection: $selectedNotes) {
            ForEach(notes) { note in
                NoteRowView(note: note)
                    .tag(note.id)
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Geen notities", systemImage: "note.text")
        } description: {
            Text("Tik op het potlood-icoon om een notitie te maken.")
        } actions: {
            Button("Nieuwe notitie") { showNewNote = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notes[index])
        }
        try? modelContext.save()
    }

    private func deleteSelected() {
        for id in selectedNotes {
            if let note = notes.first(where: { $0.id == id }) {
                if let audioURL = note.audioFileURL {
                    try? FileManager.default.removeItem(at: audioURL)
                }
                modelContext.delete(note)
            }
        }
        selectedNotes.removeAll()
        editMode = .inactive
        try? modelContext.save()
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            // Input type icon
            Image(systemName: note.inputType.systemImage)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayContent)
                    .lineLimit(2)
                    .font(.body)

                HStack {
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !note.isProcessed {
                        Spacer()
                        Label("Verwerken...", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch note.inputType {
        case .text: .blue
        case .drawing: .purple
        case .voice: .orange
        }
    }
}
