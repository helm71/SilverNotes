import SwiftUI
import AVFoundation
import WatchKit

struct VoiceRecordingWatchView: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    @Environment(\.dismiss) private var dismiss

    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var durationTimer: Timer?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var resultIsError = false
    @State private var hasMicPermission = false

    var body: some View {
        VStack(spacing: 16) {
            if showResult {
                resultView
            } else {
                recordingView
            }
        }
        .padding()
        .onAppear { checkMicPermission() }
        .onDisappear { cleanupIfNeeded() }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            ZStack {
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isRecording ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isRecording)
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 28))
                    .foregroundStyle(isRecording ? .red : .blue)
            }

            if isRecording {
                Text(formatDuration(recordingDuration))
                    .font(.system(.title3, design: .monospaced))

                Button {
                    stopAndSend()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                if !hasMicPermission {
                    Text("Microfoon toegang vereist")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if !handler.isPhoneReachable {
                    Text("iPhone niet bereikbaar")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("Tik om op te nemen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    startRecording()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(hasMicPermission ? Color.blue : Color.gray)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!hasMicPermission)
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(resultIsError ? .red : .green)

            Text(resultMessage)
                .font(.caption)
                .multilineTextAlignment(.center)

            Button("Sluiten") { dismiss() }
                .font(.caption.weight(.semibold))
        }
    }

    private func checkMicPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            hasMicPermission = true
        case .undetermined:
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                await MainActor.run { hasMicPermission = granted }
            }
        case .denied:
            hasMicPermission = false
        @unknown default:
            hasMicPermission = false
        }
    }

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-\(UUID().uuidString).m4a")

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard audioRecorder?.record() == true else {
                resultMessage = "Opname kon niet starten"
                resultIsError = true
                showResult = true
                return
            }
            recordingURL = url
            isRecording = true
            recordingDuration = 0
            WKInterfaceDevice.current().play(.start)

            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
            }
        } catch {
            resultMessage = "Fout: \(error.localizedDescription)"
            resultIsError = true
            showResult = true
        }
    }

    private func stopAndSend() {
        durationTimer?.invalidate()
        durationTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        WKInterfaceDevice.current().play(.stop)

        guard let url = recordingURL else {
            resultMessage = "Geen opname gevonden"
            resultIsError = true
            showResult = true
            return
        }

        // Check the file actually exists and has content
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size > 1000 else {
            resultMessage = "Opname te kort of leeg"
            resultIsError = true
            showResult = true
            return
        }

        guard handler.isPhoneReachable || WCSession.default.activationState == .activated else {
            resultMessage = "iPhone niet verbonden"
            resultIsError = true
            showResult = true
            return
        }

        handler.sendAudioToPhone(fileURL: url)
        resultMessage = "Verzonden naar iPhone ✓\nWordt verwerkt..."
        resultIsError = false
        showResult = true
    }

    private func cleanupIfNeeded() {
        durationTimer?.invalidate()
        if isRecording { audioRecorder?.stop() }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
