import Foundation
import Combine
import Speech
import AVFoundation

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case noResult

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Toegang tot spraakherkenning geweigerd"
        case .recognizerUnavailable: "Spraakherkenning niet beschikbaar op dit apparaat"
        case .noResult: "Geen spraak herkend"
        }
    }
}

final class SpeechService {
    static let shared = SpeechService()

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL, localeIdentifier: String = "nl-NL") async throws -> String {
        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            // Fallback to device locale recognizer
            guard let fallback = SFSpeechRecognizer(), fallback.isAvailable else {
                throw SpeechError.recognizerUnavailable
            }
            return try await performTranscription(recognizer: fallback, audioURL: audioURL)
        }
        return try await performTranscription(recognizer: recognizer, audioURL: audioURL)
    }

    private func performTranscription(recognizer: SFSpeechRecognizer, audioURL: URL) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    resumed = true
                    let text = result.bestTranscription.formattedString
                    if text.isEmpty {
                        continuation.resume(throwing: SpeechError.noResult)
                    } else {
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }
}

// MARK: - Audio Recording

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var currentURL: URL?

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let fileName = "note-\(UUID().uuidString).m4a"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        currentURL = url
        isRecording = true
        recordingDuration = 0

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }

        return url
    }

    func stopRecording() -> URL? {
        durationTimer?.invalidate()
        durationTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        let url = currentURL
        currentURL = nil
        return url
    }
}
