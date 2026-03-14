import SwiftUI
import Combine
import WatchConnectivity

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
            .onOpenURL { url in
                if url.scheme == "silvernotes" && url.host == "record" {
                    appState.launchIntoRecording = true
                }
            }
        }
    }
}
