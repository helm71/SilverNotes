import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let newActionCount: Int
}

// MARK: - Timeline Provider

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), newActionCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date(), newActionCount: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), newActionCount: 0)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Complication Views

struct ComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    // Rode cirkel met witte S
    private var circularView: some View {
        ZStack {
            Circle()
                .fill(Color.red)
            Text("S")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .widgetURL(URL(string: "silvernotes://record"))
    }

    private var cornerView: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 18, weight: .semibold))
            .widgetAccentable()
            .widgetLabel("SilverNotes")
            .widgetURL(URL(string: "silvernotes://record"))
    }

    private var inlineView: some View {
        Label("SilverNotes opnemen", systemImage: "mic.fill")
            .widgetURL(URL(string: "silvernotes://record"))
    }
}

// MARK: - Widget Configuration

struct SilverNotesComplication: Widget {
    let kind: String = "SilverNotesComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("SilverNotes")
        .description("Tik om direct een spraaknotitie op te nemen.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Widget Bundle

@main
struct SilverNotesComplicationBundle: WidgetBundle {
    var body: some Widget {
        SilverNotesComplication()
    }
}
