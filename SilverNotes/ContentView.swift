import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<Action> { $0.statusRaw == "new" }) var newActions: [Action]
    @State var selectedTab = 1

    init() {}

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Notities", systemImage: "note.text", value: 0) {
                NoteListView()
            }
            Tab("Acties", systemImage: "checkmark.circle", value: 1) {
                ActionListView()
            }
            .badge(newActions.count)
            Tab("Instellingen", systemImage: "gear", value: 2) {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToActionsTab)) { _ in
            selectedTab = 1
        }
    }
}

extension Notification.Name {
    static let switchToActionsTab = Notification.Name("switchToActionsTab")
}

#Preview {
    ContentView()
        .modelContainer(for: [Note.self, Action.self], inMemory: true)
}
