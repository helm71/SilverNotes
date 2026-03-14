import Foundation
import Combine
import WatchConnectivity

struct WatchAction: Identifiable {
    let id: UUID
    let title: String
    let detail: String?
    let dueDate: Date?
    var status: String

    var statusDisplay: String {
        switch status {
        case "new": "Nieuw"
        case "open": "Open"
        case "pending": "In behandeling"
        case "closed": "Gesloten"
        default: status
        }
    }
}

final class WatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = WatchConnectivityHandler()

    @Published var actions: [WatchAction] = []
    @Published var isPhoneReachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendAudioToPhone(fileURL: URL) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferFile(fileURL, metadata: ["type": "voiceNote"])
    }

    func updateActionStatus(actionId: UUID, newStatus: String) {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["updateAction": actionId.uuidString, "status": newStatus],
            replyHandler: nil,
            errorHandler: { error in print("[Watch] Send error: \(error)") }
        )
    }
}

extension WatchConnectivityHandler: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let rawActions = applicationContext["actions"] as? [[String: Any]] else { return }

        let parsed: [WatchAction] = rawActions.compactMap { dict in
            guard let idStr = dict["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let title = dict["title"] as? String,
                  let status = dict["status"] as? String else { return nil }
            let dueDate = (dict["dueDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            return WatchAction(
                id: id,
                title: title,
                detail: dict["detail"] as? String,
                dueDate: dueDate,
                status: status
            )
        }

        DispatchQueue.main.async {
            self.actions = parsed
        }
    }
}
