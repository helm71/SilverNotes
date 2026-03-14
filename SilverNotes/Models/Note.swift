import Foundation
import SwiftData

enum InputType: String, Codable {
    case text, drawing, voice

    var displayName: String {
        switch self {
        case .text: "Tekst"
        case .drawing: "Tekening"
        case .voice: "Stem"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.cursor"
        case .drawing: "pencil.and.scribble"
        case .voice: "mic.fill"
        }
    }
}

@Model
final class Note {
    var id: UUID
    var createdAt: Date
    var content: String
    var drawingData: Data?
    var audioFileName: String?
    var inputTypeRaw: String
    var isProcessed: Bool

    var inputType: InputType {
        get { InputType(rawValue: inputTypeRaw) ?? .text }
        set { inputTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        content: String = "",
        drawingData: Data? = nil,
        audioFileName: String? = nil,
        inputType: InputType = .text,
        isProcessed: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.drawingData = drawingData
        self.audioFileName = audioFileName
        self.inputTypeRaw = inputType.rawValue
        self.isProcessed = isProcessed
    }

    var audioFileURL: URL? {
        guard let fn = audioFileName else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fn)
    }

    var displayContent: String {
        switch inputType {
        case .text: return content.isEmpty ? "Lege notitie" : content
        case .drawing: return "Tekening"
        case .voice: return content.isEmpty ? "Spraakopname" : content
        }
    }
}
