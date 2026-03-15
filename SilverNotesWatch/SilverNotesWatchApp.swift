import SwiftUI
import Combine
import WatchConnectivity
import WidgetKit

class WatchAppState: ObservableObject {
    @Published var launchIntoRecording = false
    /// true wanneer de opname via complicatie is gestart en klaar is
    @Published var showPostRecordingDone = false
    static let shared = WatchAppState()
    private init() {}
}

/// Kort groen vinkje na opname vanuit complicatie.
/// Na 1 seconde verdwijnt het — gebruiker drukt Digital Crown → watch face.
private struct RecordingDoneView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Verzonden")
                .font(.caption.weight(.semibold))
        }
    }
}

@main
struct SilverNotesWatchApp: App {
    @StateObject private var appState = WatchAppState.shared
    @StateObject private var connectivityHandler = WatchConnectivityHandler.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.launchIntoRecording {
                    // Gestart via complicatie: direct opnemen
                    QuickRecordView {
                        appState.launchIntoRecording = false
                        appState.showPostRecordingDone = true
                        // Na 1 seconde vinkje weghalen; gebruiker drukt crown → watch face
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            appState.showPostRecordingDone = false
                        }
                    }
                    .environmentObject(connectivityHandler)

                } else if appState.showPostRecordingDone {
                    // Kort groen vinkje — GEEN MainWatchView
                    RecordingDoneView()

                } else {
                    // Normaal opstarten: hoofdscherm
                    MainWatchView(openRecordingOnLaunch: .constant(false))
                        .environmentObject(connectivityHandler)
                }
            }
            .onAppear {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onOpenURL { url in
                print("[SilverNotes] onOpenURL called: \(url.absoluteString)")
                if url.scheme == "silvernotes" {
                    appState.showPostRecordingDone = false
                    appState.launchIntoRecording = true
                }
            }
        }
    }
}
