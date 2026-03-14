import SwiftUI
import WatchConnectivity

@main
struct SilverNotesWatchApp: App {
    @State private var launchIntoRecording = false
    @StateObject private var connectivityHandler = WatchConnectivityHandler.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if launchIntoRecording {
                    // Launched from complication — go straight into recording
                    QuickRecordView {
                        launchIntoRecording = false
                    }
                    .environmentObject(connectivityHandler)
                } else {
                    MainWatchView(openRecordingOnLaunch: .constant(false))
                        .environmentObject(connectivityHandler)
                }
            }
            .onOpenURL { url in
                if url.scheme == "silvernotes" && url.host == "record" {
                    launchIntoRecording = true
                }
            }
        }
    }
}
