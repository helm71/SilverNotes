import Foundation
import SwiftData
import SwiftUI

enum ActionStatus: String, Codable, CaseIterable, Identifiable {
    case new, open, pending, closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: "Nieuw"
        case .open: "Open"
        case .pending: "In behandeling"
        case .closed: "Gesloten"
        }
    }

    var color: Color {
        switch self {
        case .new: .blue
        case .open: .orange
        case .pending: .purple
        case .closed: .secondary
        }
    }

    var next: ActionStatus {
        switch self {
        case .new: .open
        case .open: .pending
        case .pending: .closed
        case .closed: .new
        }
    }
}

@Model
final class Action {
    var id: UUID
    var createdAt: Date
    var title: String
    var detail: String?
    var dueDate: Date?
    var statusRaw: String
    var sourceNoteId: UUID?
    var notificationIdentifier: String
    var categoryName: String?

    var status: ActionStatus {
        get { ActionStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        detail: String? = nil,
        dueDate: Date? = nil,
        status: ActionStatus = .new,
        sourceNoteId: UUID? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
        self.sourceNoteId = sourceNoteId
        self.notificationIdentifier = "action-\(id.uuidString)"
        self.categoryName = categoryName
    }
}
