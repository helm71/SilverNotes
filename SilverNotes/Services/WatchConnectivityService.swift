import Foundation
import Combine
import WatchConnectivity
import SwiftData

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isReachable = false

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
            let authorized = await SpeechService.shared.requestAuthorization()
            guard authorized else { return }

            do {
                let locale = AppSettings.shared.speechLocale
                let transcript = try await SpeechService.shared.transcribe(audioURL: url, localeIdentifier: locale)
                let note = Note(content: transcript, inputType: .voice, isProcessed: false)
                note.audioFileName = url.lastPathComponent

                await MainActor.run {
                    context.insert(note)
                    try? context.save()
                }

                let candidates = await LLMService.shared.extractActions(from: transcript, noteDate: Date())
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
                }
            } catch {
                print("[WatchConnectivity] Audio processing error: \(error)")
            }
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
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
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-\(UUID().uuidString).m4a")
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: tempURL)
            NotificationCenter.default.post(name: .watchAudioReceived, object: tempURL)
        } catch {
            print("[WatchConnectivity] File receive error: \(error)")
        }
    }
}

extension Notification.Name {
    static let watchAudioReceived = Notification.Name("watchAudioReceived")
}
