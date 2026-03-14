import Foundation
import Combine
@preconcurrency import WatchConnectivity
import SwiftData

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isReachable = false

    /// Set by SilverNotesApp.init() so we can create ModelContexts on demand.
    var modelContainer: ModelContainer?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendActionsToWatch(actions: [Action]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }

        let payload: [[String: Any]] = actions.prefix(50).map { action in
            var dict: [String: Any] = [
                "id": action.id.uuidString,
                "title": action.title,
                "status": action.status.rawValue,
                "createdAt": action.createdAt.timeIntervalSince1970
            ]
            if let due = action.dueDate { dict["dueDate"] = due.timeIntervalSince1970 }
            if let detail = action.detail { dict["detail"] = detail }
            return dict
        }

        do {
            try WCSession.default.updateApplicationContext(["actions": payload])
        } catch {
            print("[WatchConnectivity] Context update error: \(error)")
        }
    }

    func processReceivedAudio(url: URL, context: ModelContext) {
        Task {
            print("[WatchConnectivity] Processing audio: \(url.lastPathComponent)")

            // Try speech transcription
            var transcript: String? = nil
            let authorized = await SpeechService.shared.requestAuthorization()
            if authorized {
                do {
                    let locale = AppSettings.shared.speechLocale
                    transcript = try await SpeechService.shared.transcribe(audioURL: url, localeIdentifier: locale)
                    print("[WatchConnectivity] Transcript: \(transcript ?? "nil")")
                } catch {
                    print("[WatchConnectivity] Transcription error: \(error)")
                }
            } else {
                print("[WatchConnectivity] Speech not authorized")
            }

            // Always create a note — even if transcription failed
            let noteContent = transcript?.isEmpty == false
                ? transcript!
                : "🎙 Spraaknotitie van Apple Watch (transcriptie niet beschikbaar)"

            let note = Note(content: noteContent, inputType: .voice, isProcessed: false)
            note.audioFileName = url.lastPathComponent

            await MainActor.run {
                context.insert(note)
                try? context.save()
                print("[WatchConnectivity] Note saved: \(noteContent.prefix(60))")
            }

            // Only extract actions if we have a real transcript
            if let text = transcript, !text.isEmpty {
                let candidates = await LLMService.shared.extractActions(from: text, noteDate: Date())
                await MainActor.run {
                    note.isProcessed = true
                    for candidate in candidates {
                        let action = Action(
                            title: candidate.title,
                            detail: candidate.detail,
                            dueDate: candidate.dueDate,
                            sourceNoteId: note.id
                        )
                        context.insert(action)
                        NotificationService.shared.scheduleNotification(for: action)
                    }
                    try? context.save()
                    print("[WatchConnectivity] \(candidates.count) actions extracted")
                }
            } else {
                await MainActor.run {
                    note.isProcessed = true
                    try? context.save()
                }
            }
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith activationState: WCSessionActivationState,
                              error: Error?) {
        print("[WatchConnectivity] Activation: \(activationState.rawValue), error: \(String(describing: error))")
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("[WatchConnectivity] Received file: \(file.fileURL.lastPathComponent), metadata: \(String(describing: file.metadata))")

        // Copy the file before the system cleans it up
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-\(UUID().uuidString).m4a")
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: dest)
        } catch {
            print("[WatchConnectivity] Copy error: \(error)")
            return
        }

        guard let container = modelContainer else {
            print("[WatchConnectivity] ⚠️ modelContainer not set — cannot process audio")
            return
        }
        let context = ModelContext(container)
        processReceivedAudio(url: dest, context: context)
    }
}

extension Notification.Name {
    static let watchAudioReceived = Notification.Name("watchAudioReceived")
}
