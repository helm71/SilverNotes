import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let newActionCount: Int
}

// MARK: - Timeline Provider

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), newActionCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date(), newActionCount: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), newActionCount: 0)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                if entry.newActionCount > 0 {
                    Text("\(entry.newActionCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
        }
        .widgetURL(URL(string: "silvernotes://record"))
    }

    private var cornerView: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 16, weight: .semibold))
            .widgetLabel {
                if entry.newActionCount > 0 {
                    Text("\(entry.newActionCount) nieuw")
                } else {
                    Text("SilverNotes")
                }
            }
            .widgetURL(URL(string: "silvernotes://record"))
    }

    private var inlineView: some View {
        Label {
            if entry.newActionCount > 0 {
                Text("\(entry.newActionCount) nieuwe acties")
            } else {
                Text("SilverNotes")
            }
        } icon: {
            Image(systemName: "mic.fill")
        }
        .widgetURL(URL(string: "silvernotes://record"))
    }
}

// MARK: - Widget Configuration

struct SilverNotesComplication: Widget {
    let kind: String = "SilverNotesComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("SilverNotes")
        .description("Snel een voice notitie opnemen. Tik om direct op te nemen.")
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
