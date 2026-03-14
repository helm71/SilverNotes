import SwiftUI
import SwiftData
import UserNotifications

@main
struct SilverNotesApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: .watchAudioReceived)) { notification in
                    // Handled via WatchConnectivityService
                }
        }
        .modelContainer(for: [Note.self, Action.self])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize services
        _ = NotificationService.shared
        _ = WatchConnectivityService.shared

        Task {
            await NotificationService.shared.requestAuthorization()
        }

        return true
    }
}
