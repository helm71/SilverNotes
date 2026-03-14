import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var notificationLeadTime: Int {
        didSet { UserDefaults.standard.set(notificationLeadTime, forKey: Keys.notificationLeadTime) }
    }

    @Published var snoozeDuration: Int {
        didSet { UserDefaults.standard.set(snoozeDuration, forKey: Keys.snoozeDuration) }
    }

    @Published var speechLocale: String {
        didSet { UserDefaults.standard.set(speechLocale, forKey: Keys.speechLocale) }
    }

    private enum Keys {
        static let notificationLeadTime = "notificationLeadTime"
        static let snoozeDuration = "snoozeDuration"
        static let speechLocale = "speechLocale"
    }

    private init() {
        let leadTime = UserDefaults.standard.integer(forKey: Keys.notificationLeadTime)
        self.notificationLeadTime = leadTime == 0 ? 10 : leadTime
        let snooze = UserDefaults.standard.integer(forKey: Keys.snoozeDuration)
        self.snoozeDuration = snooze == 0 ? 10 : snooze
        self.speechLocale = UserDefaults.standard.string(forKey: Keys.speechLocale) ?? "nl-NL"
    }
}
