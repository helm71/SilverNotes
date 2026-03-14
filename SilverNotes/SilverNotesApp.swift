import SwiftUI
import SwiftData
import UserNotifications

@main
struct SilverNotesApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Note.self, Action.self)
            // Make the container available to WatchConnectivityService
            // so it can process incoming audio files without needing a SwiftUI context
            WatchConnectivityService.shared.modelContainer = container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = NotificationService.shared
        _ = WatchConnectivityService.shared

        Task {
            await NotificationService.shared.requestAuthorization()
        }

        return true
    }
}
