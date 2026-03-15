import SwiftUI
import Combine
import WatchConnectivity
import WidgetKit

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
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onOpenURL { url in
                print("[SilverNotes] onOpenURL called: \(url.absoluteString)")
                if url.scheme == "silvernotes" {
                    appState.launchIntoRecording = true
                }
            }
        }
    }
}
