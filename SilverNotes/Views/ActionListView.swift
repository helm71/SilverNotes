import SwiftUI
import SwiftData
import MessageUI

struct ActionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Action.dueDate) private var allActions: [Action]

    @State private var selectedFilter: ActionStatus? = nil
    @State private var editMode: EditMode = .inactive
    @State private var selectedActions = Set<Action.ID>()
    @State private var showBulkStatusPicker = false
    @State private var showDeleteConfirm = false
    @State private var selectedAction: Action?
    @State private var mailAction: Action?
    @State private var showMailCompose = false
    @State private var showMailUnavailable = false
    @ObservedObject private var settings = AppSettings.shared

    private var filteredActions: [Action] {
        guard let filter = selectedFilter else { return allActions }
        return allActions.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Group {
                    if filteredActions.isEmpty {
                        emptyStateView
                    } else {
                        actionList
                    }
                }
            }
            .navigationTitle("Acties")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !allActions.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if editMode == .active && !selectedActions.isEmpty {
                        Button { showBulkStatusPicker = true } label: {
                            Label("Status", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Verwijder", systemImage: "trash")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(item: $selectedAction) { action in
                ActionDetailView(action: action)
            }
            .confirmationDialog("Status wijzigen", isPresented: $showBulkStatusPicker) {
                ForEach(ActionStatus.allCases) { status in
                    Button(status.displayName) { setBulkStatus(status) }
                }
                Button("Annuleer", role: .cancel) {}
            }
            .confirmationDialog("Verwijder \(selectedActions.count) actie(s)?", isPresented: $showDeleteConfirm) {
                Button("Verwijder", role: .destructive) { deleteSelected() }
                Button("Annuleer", role: .cancel) {}
            }
        }
        .sheet(isPresented: $showMailCompose) {
            if let action = mailAction {
                MailComposeView(
                    recipient: settings.taskMailRecipient,
                    subject: "Taak: \(action.title)",
                    body: MailTaskService.shared.mailBody(for: action),
                    icsData: MailTaskService.shared.generateICS(for: action),
                    isPresented: $showMailCompose
                ) {
                    action.isMailed = true
                    try? modelContext.save()
                }
            }
        }
        .alert("Mail niet beschikbaar", isPresented: $showMailUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Er is geen e-mailaccount ingesteld op dit apparaat.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationActionReceived)) { notification in
            handleNotificationResponse(notification)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Alle", isSelected: selectedFilter == nil, count: allActions.count) {
                    selectedFilter = nil
                }
                ForEach(ActionStatus.allCases) { status in
                    let count = allActions.filter { $0.status == status }.count
                    FilterChip(title: status.displayName, color: status.color, isSelected: selectedFilter == status, count: count) {
                        selectedFilter = (selectedFilter == status) ? nil : status
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var actionList: some View {
        List(selection: $selectedActions) {
            ForEach(filteredActions) { action in
                ActionRowView(action: action)
                    .tag(action.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editMode == .inactive {
                            selectedAction = action
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            withAnimation { action.status = action.status.next }
                            try? modelContext.save()
                        } label: {
                            Label("Volgende status", systemImage: "arrow.right")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
                            modelContext.delete(action)
                            try? modelContext.save()
                        } label: {
                            Label("Verwijder", systemImage: "trash")
                        }
                        if !settings.taskMailRecipient.isEmpty {
                            Button {
                                if MailTaskService.shared.canSendMail() {
                                    mailAction = action
                                    showMailCompose = true
                                } else {
                                    showMailUnavailable = true
                                }
                            } label: {
                                Label("Mail", systemImage: action.isMailed ? "envelope.badge.fill" : "envelope")
                            }
                            .tint(.indigo)
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Geen acties", systemImage: "checkmark.circle")
        } description: {
            if selectedFilter != nil {
                Text("Geen acties met status '\(selectedFilter!.displayName)'.")
            } else {
                Text("Maak een notitie aan om automatisch acties te genereren.")
            }
        }
    }

    private func setBulkStatus(_ status: ActionStatus) {
        for id in selectedActions {
            if let action = allActions.first(where: { $0.id == id }) {
                action.status = status
                if status == .closed {
                    NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
                }
            }
        }
        selectedActions.removeAll()
        editMode = .inactive
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteSelected() {
        for id in selectedActions {
            if let action = allActions.first(where: { $0.id == id }) {
                NotificationService.shared.cancelNotification(identifier: action.notificationIdentifier)
                modelContext.delete(action)
            }
        }
        selectedActions.removeAll()
        editMode = .inactive
        try? modelContext.save()
    }

    private func handleNotificationResponse(_ notification: Notification) {
        guard let actionId = notification.userInfo?["actionId"] as? UUID,
              let action = allActions.first(where: { $0.id == actionId }),
              let responseStr = notification.userInfo?["response"] as? String else { return }

        switch NotificationService.ActionIdentifier(rawValue: responseStr) {
        case .complete:
            action.status = .closed
            if let notifId = notification.userInfo?["notificationId"] as? String {
                NotificationService.shared.cancelNotification(identifier: notifId)
            }
            try? modelContext.save()
        default:
            break
        }
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = .blue
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

struct ActionRowView: View {
    let action: Action

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(action.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.body)
                    .strikethrough(action.status == .closed)
                    .foregroundStyle(action.status == .closed ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let dueDate = action.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(dueDate < Date() && action.status != .closed ? .red : .secondary)
                    }
                    Text(action.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(action.status.color.opacity(0.15))
                        .foregroundStyle(action.status.color)
                        .clipShape(Capsule())
                    if let category = action.categoryName {
                        Label(category, systemImage: "tag.fill")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(Color.blue.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
