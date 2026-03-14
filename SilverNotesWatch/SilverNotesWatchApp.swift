import SwiftUI
import Combine
import WatchConnectivity
import WidgetKit

// Separate ObservableObject so @Published changes reliably trigger view updates
class WatchAppState: ObservableObject {
    @Published var launchIntoRecording = false
    static let shared = WatchAppState()
    private init() {}
}

@main
struct SilverNotesWatchApp: App {
    @StateObject private var appState = WatchAppState.shared
    @StateObject private var connectivityHandler = WatchConnectivityHandler.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.launchIntoRecording {
                    QuickRecordView {
                        appState.launchIntoRecording = false
                    }
                    .environmentObject(connectivityHandler)
                } else {
                    MainWatchView(openRecordingOnLaunch: .constant(false))
                        .environmentObject(connectivityHandler)
                }
            }
            .onAppear {
                // Force complication to reload with latest code
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onOpenURL { url in
                print("[SilverNotes] onOpenURL called: \(url.absoluteString)")
                // Accept any silvernotes:// URL → go straight into recording
                if url.scheme == "silvernotes" {
                    appState.launchIntoRecording = true
                }
            }
        }
    }
}
