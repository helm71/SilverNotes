import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var settings = AppSettings.shared
    @State private var showResetConfirm = false
    @State private var showAIUnavailable = false

    private let supportedLocales = [
        ("nl-NL", "Nederlands"),
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("de-DE", "Deutsch"),
        ("fr-FR", "Français"),
        ("es-ES", "Español")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("On-device AI", systemImage: "brain")
                        Spacer()
                        aiStatusBadge
                    }
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("SilverNotes gebruikt uitsluitend on-device AI van Apple. Vereist iPhone 15 Pro of nieuwer met Apple Intelligence ingeschakeld.")
                }

                Section("Notificaties") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Aanlooptijd")
                            Spacer()
                            Text("\(settings.notificationLeadTime) min")
                                .foregroundStyle(.secondary)
                        }
                        Stepper("", value: $settings.notificationLeadTime, in: 1...60, step: 1)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Snooze-duur")
                            Spacer()
                            Text("\(settings.snoozeDuration) min")
                                .foregroundStyle(.secondary)
                        }
                        Stepper("", value: $settings.snoozeDuration, in: 5...60, step: 5)
                            .labelsHidden()
                    }
                }

                Section("Spraakherkenning") {
                    Picker("Taal", selection: $settings.speechLocale) {
                        ForEach(supportedLocales, id: \.0) { identifier, name in
                            Text(name).tag(identifier)
                        }
                    }
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if settings.llmExtraInstructions.isEmpty {
                            Text("Aanvullende instructies voor de AI, bijv. 'Antwoord altijd in het Engels' of 'Gebruik alleen de categorieën Werk en Privé'.")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $settings.llmExtraInstructions)
                            .frame(minHeight: 100)
                            .font(.body)
                    }
                } header: {
                    Text("AI-instructies")
                } footer: {
                    Text("Deze tekst wordt bij elke analyse meegestuurd. Leeg laten voor standaardgedrag.")
                }

                Section {
                    TextField("E-mailadres ontvanger", text: $settings.taskMailRecipient)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Toggle("Automatisch mailen bij nieuwe actie", isOn: $settings.autoMailActions)
                        .disabled(settings.taskMailRecipient.isEmpty)
                } header: {
                    Text("E-mail integratie")
                } footer: {
                    Text("Acties worden als taak (.ics) gemaild via de Mail-app. Werkt met Outlook, Exchange en Apple Mail. Bij 'Automatisch mailen' opent de Mail-app zodra je een nieuwe actie opent.")
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Verwijder alle data", systemImage: "trash.fill")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Verwijdert alle notities en acties permanent.")
                }

                Section {
                    HStack {
                        Text("Versie")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Over SilverNotes")
                }
            }
            .navigationTitle("Instellingen")
            .confirmationDialog("Alle data verwijderen?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Verwijder alles", role: .destructive) { resetAllData() }
                Button("Annuleer", role: .cancel) {}
            } message: {
                Text("Dit verwijdert alle notities en acties permanent en kan niet ongedaan worden gemaakt.")
            }
        }
    }

    @ViewBuilder
    private var aiStatusBadge: some View {
        let available = LLMService.shared.isAvailable
        Label(available ? "Beschikbaar" : "Niet beschikbaar", systemImage: available ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption)
            .foregroundStyle(available ? .green : .orange)
            .labelStyle(.titleAndIcon)
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: Note.self)
            try modelContext.delete(model: Action.self)
            try modelContext.save()
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        } catch {
            print("[Settings] Reset error: \(error)")
        }
    }
}
