import SwiftUI
import SwiftData
import AVFoundation

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var inputType: InputType = .text
    @State private var textContent: String = ""
    @State private var drawingData: Data?
    @State private var audioRecorder = AudioRecorder()
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasRequestedMicPermission = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input type selector
                Picker("Invoermethode", selection: $inputType) {
                    ForEach([InputType.text, .drawing, .voice], id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Input area
                Group {
                    switch inputType {
                    case .text:
                        textInputView
                    case .drawing:
                        DrawingEditorView(drawingData: $drawingData)
                    case .voice:
                        voiceInputView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isProcessing {
                    processingView
                }
            }
            .navigationTitle("Nieuwe notitie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") {
                        if audioRecorder.isRecording {
                            _ = audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        Task { await saveNote() }
                    }
                    .disabled(isProcessing || !hasContent)
                    .fontWeight(.semibold)
                }
            }
            .alert("Fout", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Onbekende fout")
            }
            .interactiveDismissDisabled(isProcessing)
        }
    }

    private var hasContent: Bool {
        switch inputType {
        case .text: return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .drawing: return drawingData != nil && drawingData!.count > 100
        case .voice: return audioRecorder.isRecording == false && hasRecordedAudio
        }
    }

    @State private var hasRecordedAudio = false

    private var textInputView: some View {
        TextEditor(text: $textContent)
            .font(.body)
            .padding()
            .overlay(alignment: .topLeading) {
                if textContent.isEmpty {
                    Text("Schrijf hier je notitie...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
    }

    private var voiceInputView: some View {
        VStack(spacing: 32) {
            Spacer()

            if audioRecorder.isRecording {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 90, height: 90)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.red)
                    }

                    Text(formatDuration(audioRecorder.recordingDuration))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button {
                        stopRecording()
                    } label: {
                        Label("Stop opname", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            } else if hasRecordedAudio {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("Opname gereed")
                        .font(.title3)
                        .fontWeight(.medium)
                    Button {
                        hasRecordedAudio = false
                        Task { await startRecording() }
                    } label: {
                        Label("Opnieuw opnemen", systemImage: "mic")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Button {
                        Task { await startRecording() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 90, height: 90)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                        }
                    }
                    Text("Tik om op te nemen")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(processingMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private func startRecording() async {
        if !hasRequestedMicPermission {
            let granted = await AVAudioApplication.requestRecordPermission()
            hasRequestedMicPermission = true
            guard granted else {
                errorMessage = "Microfoon toegang vereist voor spraakopname."
                showError = true
                return
            }
        }
        do {
            _ = try audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() {
        _ = audioRecorder.stopRecording()
        hasRecordedAudio = true
    }

    private func saveNote() async {
        isProcessing = true

        let note: Note

        switch inputType {
        case .text:
            let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            note = Note(content: trimmed, inputType: .text)
            modelContext.insert(note)
            try? modelContext.save()
            await processNote(note: note, text: trimmed)

        case .drawing:
            note = Note(drawingData: drawingData, inputType: .drawing)
            modelContext.insert(note)
            note.isProcessed = true
            try? modelContext.save()

        case .voice:
            if audioRecorder.isRecording {
                stopRecording()
            }
            guard let audioURL = audioRecorder.stopRecording() ?? findLastRecordedURL() else {
                isProcessing = false
                return
            }

            processingMessage = "Transcriberen..."
            note = Note(audioFileName: audioURL.lastPathComponent, inputType: .voice)
            modelContext.insert(note)
            try? modelContext.save()

            let authorized = await SpeechService.shared.requestAuthorization()
            if authorized {
                do {
                    let transcript = try await SpeechService.shared.transcribe(
                        audioURL: audioURL,
                        localeIdentifier: AppSettings.shared.speechLocale
                    )
                    note.content = transcript
                    try? modelContext.save()
                    await processNote(note: note, text: transcript)
                } catch {
                    note.isProcessed = true
                    try? modelContext.save()
                }
            } else {
                note.isProcessed = true
                try? modelContext.save()
            }
        }

        isProcessing = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func processNote(note: Note, text: String) async {
        processingMessage = "Acties analyseren..."
        let candidates = await LLMService.shared.extractActions(from: text)
        note.isProcessed = true

        for candidate in candidates {
            let action = Action(
                title: candidate.title,
                detail: candidate.detail,
                dueDate: candidate.dueDate,
                sourceNoteId: note.id
            )
            modelContext.insert(action)
            NotificationService.shared.scheduleNotification(for: action)
        }
        try? modelContext.save()
    }

    private func findLastRecordedURL() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.creationDateKey]))?.filter { $0.pathExtension == "m4a" }
        return files?.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }.first
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private extension URL {
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}
