import SwiftUI
import WatchConnectivity

@main
struct SilverNotesWatchApp: App {
    @State private var openRecordingOnLaunch = false
    @StateObject private var connectivityHandler = WatchConnectivityHandler.shared

    var body: some Scene {
        WindowGroup {
            MainWatchView(openRecordingOnLaunch: $openRecordingOnLaunch)
                .environmentObject(connectivityHandler)
                .onOpenURL { url in
                    if url.scheme == "silvernotes" && url.host == "record" {
                        openRecordingOnLaunch = true
                    }
                }
        }
    }
}
