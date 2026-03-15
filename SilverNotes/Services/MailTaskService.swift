import Foundation
import MessageUI
import SwiftUI

// MARK: - ICS / VTODO generator

final class MailTaskService {
    static let shared = MailTaskService()
    private init() {}

    func canSendMail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// Builds a valid iCalendar VTODO attachment for Outlook / Exchange / Apple Mail.
    func generateICS(for action: Action) -> Data {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//SilverNotes//iOS//NL",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VTODO",
            "UID:\(action.id.uuidString)@silvernotes",
            "DTSTAMP:\(df.string(from: Date()))",
            "CREATED:\(df.string(from: action.createdAt))",
            "SUMMARY:\(icsEscape(action.title))",
            "PRIORITY:5",
            "STATUS:NEEDS-ACTION"
        ]

        if let detail = action.detail, !detail.isEmpty {
            lines.append("DESCRIPTION:\(icsEscape(detail))")
        }
        if let dueDate = action.dueDate {
            lines.append("DUE:\(df.string(from: dueDate))")
        }
        if let category = action.categoryName {
            lines.append("CATEGORIES:\(icsEscape(category))")
        }

        lines += ["END:VTODO", "END:VCALENDAR"]
        // iCalendar spec requires CRLF line endings
        return lines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
    }

    func mailBody(for action: Action) -> String {
        var parts = ["Actie aangemaakt via SilverNotes", ""]
        parts.append("Titel: \(action.title)")
        if let detail = action.detail, !detail.isEmpty {
            parts.append("Details: \(detail)")
        }
        if let dueDate = action.dueDate {
            let df = DateFormatter()
            df.locale = Locale.current
            df.dateStyle = .long
            df.timeStyle = .short
            parts.append("Deadline: \(df.string(from: dueDate))")
        }
        if let category = action.categoryName {
            parts.append("Categorie: \(category)")
        }
        parts += ["", "Verstuurd vanuit SilverNotes"]
        return parts.joined(separator: "\n")
    }

    private func icsEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}

// MARK: - SwiftUI wrapper for MFMailComposeViewController

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let icsData: Data
    @Binding var isPresented: Bool
    var onSent: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onSent: onSent)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if !recipient.isEmpty { vc.setToRecipients([recipient]) }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.addAttachmentData(icsData, mimeType: "text/calendar", fileName: "taak.ics")
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        var onSent: (() -> Void)?

        init(isPresented: Binding<Bool>, onSent: (() -> Void)?) {
            _isPresented = isPresented
            self.onSent = onSent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            isPresented = false
            if result == .sent { onSent?() }
        }
    }
}
