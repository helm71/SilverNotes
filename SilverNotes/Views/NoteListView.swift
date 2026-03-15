import SwiftUI
import SwiftData
import AVFoundation

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
            let note = notes[index]
            // Delete associated audio file if present
            if let audioURL = note.audioFileURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            modelContext.delete(note)
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

// MARK: - Note Row

struct NoteRowView: View {
    let note: Note
    @Environment(\.modelContext) private var modelContext
    @State private var isReprocessing = false

    var body: some View {
        HStack(spacing: 12) {
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

                    if !note.isProcessed || isReprocessing {
                        Spacer()
                        Label(isReprocessing ? "Herverwerken..." : "Verwerken...", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Play button for voice notes whose audio file still exists
            if note.inputType == .voice,
               let audioURL = note.audioFileURL,
               FileManager.default.fileExists(atPath: audioURL.path) {
                AudioPlayerButton(url: audioURL)
            }

            // Reprocess button for notes with text content
            if note.inputType != .drawing && !note.content.isEmpty {
                Button {
                    Task { await reprocess() }
                } label: {
                    if isReprocessing {
                        ProgressView().frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isReprocessing)
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

    private func reprocess() async {
        isReprocessing = true

        // Remove existing auto-generated actions for this note
        let noteId = note.id
        let existingActions = (try? modelContext.fetch(
            FetchDescriptor<Action>(predicate: #Predicate { $0.sourceNoteId == noteId })
        )) ?? []
        for action in existingActions {
            NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
            modelContext.delete(action)
        }

        // Re-run LLM
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let knownCategoryNames = categories.map { $0.name }
        let candidates = await LLMService.shared.extractActions(
            from: note.content,
            noteDate: note.createdAt,
            knownCategories: knownCategoryNames
        )

        for candidate in candidates {
            if let catName = candidate.category {
                let trimmed = catName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                    modelContext.insert(Category(name: trimmed))
                }
            }
            let action = Action(
                title: candidate.title,
                detail: candidate.detail,
                dueDate: candidate.dueDate,
                sourceNoteId: note.id,
                categoryName: candidate.category.flatMap {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
                }
            )
            modelContext.insert(action)
            NotificationService.shared.scheduleNotification(for: action)
        }
        try? modelContext.save()
        isReprocessing = false
    }
}

// MARK: - Audio Player

private final class AudioPlayerCoordinator: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        DispatchQueue.main.async { self.onFinish?() }
    }
}

struct AudioPlayerButton: View {
    let url: URL

    @State private var player: AVAudioPlayer?
    @State private var coordinator = AudioPlayerCoordinator()
    @State private var isPlaying = false

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(isPlaying ? .red : .orange)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .onDisappear {
            player?.stop()
            player = nil
            isPlaying = false
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.stop()
            player = nil
            isPlaying = false
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let p = try AVAudioPlayer(contentsOf: url)
                coordinator.onFinish = {
                    isPlaying = false
                    player = nil
                }
                p.delegate = coordinator
                p.play()
                player = p
                isPlaying = true
            } catch {
                print("[Audio] Playback error: \(error)")
            }
        }
    }
}
