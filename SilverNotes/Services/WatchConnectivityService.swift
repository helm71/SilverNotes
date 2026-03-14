import Foundation
import Combine
import UserNotifications
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

    // Accepts a ModelContainer so the ModelContext is created on the MainActor.
    nonisolated func processReceivedAudio(url: URL, container: ModelContainer) {
        // Use Task.detached so heavy work (speech + LLM) runs on a background thread
        // and never blocks the MainActor / UI.
        Task.detached(priority: .userInitiated) {
            print("[WatchConnectivity] Processing audio: \(url.lastPathComponent)")

            // --- Speech transcription (background thread) ---
            var transcript: String? = nil
            let authorized = await SpeechService.shared.requestAuthorization()
            if authorized {
                do {
                    // AppSettings is @MainActor — read it there
                    let locale = await MainActor.run { AppSettings.shared.speechLocale }
                    transcript = try await SpeechService.shared.transcribe(audioURL: url, localeIdentifier: locale)
                    print("[WatchConnectivity] Transcript: \(transcript ?? "nil")")
                } catch {
                    print("[WatchConnectivity] Transcription error: \(error)")
                }
            } else {
                print("[WatchConnectivity] Speech not authorized")
            }

            let noteContent = transcript?.isEmpty == false
                ? transcript!
                : "🎙 Spraaknotitie van Apple Watch (transcriptie niet beschikbaar)"

            // --- Save note on MainActor ---
            let noteId: UUID = await MainActor.run {
                let ctx = ModelContext(container)
                let note = Note(content: noteContent, inputType: .voice, isProcessed: false)
                note.audioFileName = url.lastPathComponent
                ctx.insert(note)
                try? ctx.save()
                print("[WatchConnectivity] Note saved: \(noteContent.prefix(60))")
                return note.id
            }

            // --- Extract actions (background) if we have a real transcript ---
            var actionCount = 0
            if let text = transcript, !text.isEmpty {
                // Fetch known categories on MainActor
                let knownCategoryNames: [String] = await MainActor.run {
                    let ctx = ModelContext(container)
                    return ((try? ctx.fetch(FetchDescriptor<Category>())) ?? []).map { $0.name }
                }

                // LLM extraction — background thread, takes a few seconds
                let candidates = await LLMService.shared.extractActions(
                    from: text,
                    noteDate: Date(),
                    knownCategories: knownCategoryNames
                )
                print("[WatchConnectivity] LLM returned \(candidates.count) candidates")
                actionCount = candidates.count

                if !candidates.isEmpty {
                    await MainActor.run {
                        let ctx = ModelContext(container)

                        // Mark note as processed
                        let predicate = #Predicate<Note> { $0.id == noteId }
                        if let note = (try? ctx.fetch(FetchDescriptor<Note>(predicate: predicate)))?.first {
                            note.isProcessed = true
                        }

                        // Fetch categories again (fresh context)
                        let existingCats = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []

                        for candidate in candidates {
                            // Create category if LLM suggests a new one
                            if let catName = candidate.category {
                                let trimmed = catName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && !existingCats.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                                    ctx.insert(Category(name: trimmed))
                                    print("[WatchConnectivity] New category created: \(trimmed)")
                                }
                            }

                            let action = Action(
                                title: candidate.title,
                                detail: candidate.detail,
                                dueDate: candidate.dueDate,
                                sourceNoteId: noteId,
                                categoryName: candidate.category.flatMap {
                                    $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
                                }
                            )
                            ctx.insert(action)
                            NotificationService.shared.scheduleNotification(for: action)
                        }
                        try? ctx.save()
                        print("[WatchConnectivity] \(candidates.count) actions saved")
                    }
                } else {
                    await MainActor.run {
                        let ctx = ModelContext(container)
                        let predicate = #Predicate<Note> { $0.id == noteId }
                        if let note = (try? ctx.fetch(FetchDescriptor<Note>(predicate: predicate)))?.first {
                            note.isProcessed = true
                            try? ctx.save()
                        }
                    }
                }
            } else {
                await MainActor.run {
                    let ctx = ModelContext(container)
                    let predicate = #Predicate<Note> { $0.id == noteId }
                    if let note = (try? ctx.fetch(FetchDescriptor<Note>(predicate: predicate)))?.first {
                        note.isProcessed = true
                        try? ctx.save()
                    }
                }
            }

            // --- Notification + badge (MainActor) ---
            let noteCount: Int = await MainActor.run {
                let ctx = ModelContext(container)
                return (try? ctx.fetchCount(FetchDescriptor<Note>())) ?? 1
            }

            await MainActor.run {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["watch-processing"])

                let notifContent = UNMutableNotificationContent()
                notifContent.title = actionCount > 0
                    ? "📝 Notitie + \(actionCount) actie\(actionCount == 1 ? "" : "s")"
                    : "📝 Nieuwe notitie"
                notifContent.body = String(noteContent.prefix(150))
                notifContent.sound = .default
                notifContent.badge = NSNumber(value: noteCount)

                let req = UNNotificationRequest(
                    identifier: "note-\(noteId)",
                    content: notifContent,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
                NotificationService.shared.updateBadge(count: noteCount)
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
        print("[WatchConnectivity] ✅ Received file: \(file.fileURL.lastPathComponent)")

        // Immediate "processing" notification
        let processing = UNMutableNotificationContent()
        processing.title = "🎙 Spraaknotitie ontvangen"
        processing.body = "Bezig met transcriberen..."
        processing.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "watch-processing", content: processing, trigger: nil),
            withCompletionHandler: nil
        )

        // Copy file before the system cleans it up
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
        processReceivedAudio(url: dest, container: container)
    }
}

extension Notification.Name {
    static let watchAudioReceived = Notification.Name("watchAudioReceived")
}
