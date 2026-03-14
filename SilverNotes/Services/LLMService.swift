#if canImport(FoundationModels)
import FoundationModels
#endif
import Foundation

struct ActionCandidate {
    let title: String
    let detail: String?
    let dueDate: Date?
}

private struct RawAction: Decodable {
    let title: String
    let detail: String?
    let dueDate: String?
}

final class LLMService {
    static let shared = LLMService()

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    func extractActions(from text: String, noteDate: Date = Date()) async -> [ActionCandidate] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                return try await extractWithFoundationModels(text: text, noteDate: noteDate)
            } catch {
                print("[LLM] Error: \(error)")
            }
        }
        #endif
        return []
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractWithFoundationModels(text: String, noteDate: Date) async throws -> [ActionCandidate] {
        guard case .available = SystemLanguageModel.default.availability else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateString = formatter.string(from: noteDate)

        let calendar = Calendar.current
        let weekdaySymbols = ["zondag","maandag","dinsdag","woensdag","donderdag","vrijdag","zaterdag"]
        let weekdayIndex = calendar.component(.weekday, from: noteDate) - 1
        let todayName = weekdaySymbols[weekdayIndex]

        // Build next-weekday lookup for the prompt
        var weekdayExamples = ""
        for offset in 1...7 {
            let futureDate = calendar.date(byAdding: .day, value: offset, to: noteDate)!
            let futureName = weekdaySymbols[calendar.component(.weekday, from: futureDate) - 1]
            let futureDateStr = formatter.string(from: futureDate)
            weekdayExamples += "  - \(futureName) = \(futureDateStr.prefix(10))\n"
        }

        let instructions = """
        Je bent een assistent die notities analyseert en concrete acties extraheert.
        De huidige datum en tijd is: \(dateString) (\(todayName)).
        De komende dagen zijn:
        \(weekdayExamples)
        Regels voor datuminterpretatie:
        - "maandagochtend" → aanstaande maandag om 08:00
        - "morgenochtend" → morgen om 08:00
        - "vanavond" → vandaag om 20:00
        - "ochtend" zonder dag → morgen om 08:00
        - Als een dag wordt genoemd (bijv. "maandag"), gebruik dan de eerstvolgende toekomstige datum voor die dag uit de lijst hierboven.
        - Gebruik NOOIT de datum van vandaag als een toekomstige dag wordt bedoeld.
        Geef je antwoord UITSLUITEND als geldig JSON array, geen extra tekst, geen markdown code blocks.
        Gebruik dit exacte JSON formaat:
        [{"title":"Korte actietitel","detail":"extra context of null","dueDate":"ISO8601 datum/tijd of null"}]
        Als er geen acties zijn, geef dan alleen: []
        """

        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Analyseer deze notitie en extraheer alle acties met eventuele tijdstippen:\n\n\(text)"
        let response = try await session.respond(to: prompt)
        return parseActions(from: response.content, referenceDate: noteDate)
    }
    #endif

    private func parseActions(from json: String, referenceDate: Date) -> [ActionCandidate] {
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let rawActions = try? JSONDecoder().decode([RawAction].self, from: data) else {
            return []
        }
        return rawActions.compactMap { raw in
            guard !raw.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let detail = raw.detail.flatMap { $0 == "null" || $0.isEmpty ? nil : $0 }
            return ActionCandidate(
                title: raw.title,
                detail: detail,
                dueDate: parseDateString(raw.dueDate)
            )
        }
    }

    private func parseDateString(_ string: String?) -> Date? {
        guard let string, string != "null", !string.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}
