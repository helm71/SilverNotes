import SwiftUI

struct ActionListWatchView: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    @State private var selectedFilter: String? = nil

    private let filters: [(String?, String)] = [
        (nil, "Alle"),
        ("new", "Nieuw"),
        ("open", "Open"),
        ("pending", "Behandeling"),
        ("closed", "Gesloten")
    ]

    private var filteredActions: [WatchAction] {
        guard let filter = selectedFilter else { return handler.actions }
        return handler.actions.filter { $0.status == filter }
    }

    var body: some View {
        VStack {
            // Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(filters, id: \.0) { filter, name in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(name)
                                .font(.system(size: 11, weight: selectedFilter == filter ? .bold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundStyle(selectedFilter == filter ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 4)

            if filteredActions.isEmpty {
                Spacer()
                Text("Geen acties")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filteredActions) { action in
                    WatchActionRow(action: action)
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Acties")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WatchActionRow: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    let action: WatchAction

    private var statusColor: Color {
        switch action.status {
        case "new": .blue
        case "open": .orange
        case "pending": .purple
        case "closed": .gray
        default: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(action.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
            }

            if let dueDate = action.dueDate {
                Label(dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Button {
                    let next = nextStatus(action.status)
                    handler.updateActionStatus(actionId: action.id, newStatus: next)
                } label: {
                    Label("Volgende", systemImage: "arrow.right.circle")
                        .font(.system(size: 10))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Text(action.statusDisplay)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 2)
    }

    private func nextStatus(_ current: String) -> String {
        switch current {
        case "new": "open"
        case "open": "pending"
        case "pending": "closed"
        case "closed": "new"
        default: "open"
        }
    }
}
