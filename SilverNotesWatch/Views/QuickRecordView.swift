import SwiftUI
import AVFoundation
import WatchKit

/// Launched directly from the watch complication.
/// Auto-starts recording immediately, shows only a "Stop opnemen" button.
struct QuickRecordView: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    var onDismiss: () -> Void

    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var durationTimer: Timer?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var phase: Phase = .starting

    enum Phase { case starting, recording, sent, error(String) }

    var body: some View {
        switch phase {
        case .starting:
            // Brief "starting" state while AVAudio initialises
            VStack(spacing: 12) {
                ProgressView()
                Text("Starten...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { startRecording() }

        case .recording:
            VStack(spacing: 16) {
                // Pulsing mic
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 90, height: 90)
                        .scaleEffect(1.25)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isRecording)
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 68, height: 68)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                }

                Text(formatDuration(recordingDuration))
                    .font(.system(.title3, design: .monospaced))

                Button {
                    stopAndSend()
                } label: {
                    Text("Stop opnemen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding()

        case .sent:
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Verzonden ✓")
                    .font(.caption.weight(.semibold))
                Text("Wordt verwerkt op iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear {
                // Auto-close after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onDismiss()
                }
            }

        case .error(let msg):
            VStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                Button("Sluiten") { onDismiss() }
                    .font(.caption)
            }
            .padding()
        }
    }

    // MARK: - Recording logic

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quick-\(UUID().uuidString).m4a")

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
                phase = .error("Opname kon niet starten")
                return
            }
            recordingURL = url
            isRecording = true
            WKInterfaceDevice.current().play(.start)

            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
            }
            phase = .recording

        } catch {
            phase = .error("Microfoon fout:\n\(error.localizedDescription)")
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
            phase = .error("Geen opname gevonden")
            return
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size > 1000 else {
            phase = .error("Opname te kort")
            return
        }

        handler.sendAudioToPhone(fileURL: url)
        WKInterfaceDevice.current().play(.success)  // haptic bevestiging
        onDismiss()  // direct terug, geen wachttijd
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
