import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - 1. Live Activity Widget (CarPlay Dashboard & Dynamic Island)

struct LyricsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            CarPlayLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandViews.expandedView(context: context)
            } compactLeading: {
                Text(context.state.trackTitle)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: 110)
            } minimal: {
                Image(systemName: "text.quote")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// MARK: - 2. Standard Widget (CarPlay Widgets Screen / StandBy / Home Screen)

struct LyricsTimelineEntry: TimelineEntry {
    let date: Date
    let trackTitle: String
    let artistName: String
    let currentLine: String
    let nextLine: String
}

struct LyricsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricsTimelineEntry {
        LyricsTimelineEntry(
            date: Date(),
            trackTitle: "Bohemian Rhapsody",
            artistName: "Queen",
            currentLine: "Is this the real life? Is this just fantasy?",
            nextLine: "Caught in a landslide, no escape from reality"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LyricsTimelineEntry) -> Void) {
        completion(loadLatestEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricsTimelineEntry>) -> Void) {
        let entry = loadLatestEntry()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadLatestEntry() -> LyricsTimelineEntry {
        // Read active Live Activity state if running, otherwise fallback to stored defaults
        if #available(iOS 16.2, *), let active = Activity<LyricsAttributes>.activities.first {
            let state = active.content.state
            return LyricsTimelineEntry(
                date: Date(),
                trackTitle: state.trackTitle,
                artistName: state.artistName,
                currentLine: state.currentLine,
                nextLine: state.nextLine
            )
        }

        let defaults = UserDefaults.standard
        return LyricsTimelineEntry(
            date: Date(),
            trackTitle: defaults.string(forKey: "WidgetTrackTitle") ?? "LyricsCarPlay",
            artistName: defaults.string(forKey: "WidgetArtistName") ?? "Listo para reproducir",
            currentLine: defaults.string(forKey: "WidgetCurrentLine") ?? "Reproduce música en Spotify o Apple Music",
            nextLine: defaults.string(forKey: "WidgetNextLine") ?? ""
        )
    }
}

struct CarPlayStaticWidgetView: View {
    let entry: LyricsTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(entry.trackTitle)
                    .font(.caption.bold())
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)

                Text("• \(entry.artistName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            Text(entry.currentLine)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.80)

            if !entry.nextLine.isEmpty {
                Text(entry.nextLine)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
    }
}

struct LyricsCarPlayStandbyWidget: Widget {
    let kind: String = "LyricsCarPlayStandbyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricsTimelineProvider()) { entry in
            CarPlayStaticWidgetView(entry: entry)
        }
        .configurationDisplayName("CarPlay Lyrics")
        .description("Muestra la letra sincronizada en grande en la pantalla de Widgets de CarPlay.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Main Widget Bundle (Includes both Punto 1 & Punto 2)

@main
struct LyricsWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivityWidget()
        LyricsCarPlayStandbyWidget()
    }
}
