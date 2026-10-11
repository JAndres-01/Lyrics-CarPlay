import ActivityKit
import SwiftUI
import UIKit
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
                Image(systemName: "text.quote")
                    .foregroundColor(.accentColor)
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: 140)
            } minimal: {
                Image(systemName: "text.quote")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// MARK: - 2. Standard Widget (CarPlay Widgets Screen / StandBy / Home Screen)

private struct WidgetScheduledLineDTO: Codable {
    let date: Date
    let currentLine: String
    let nextLine: String
}

private struct WidgetSyncPayloadDTO: Codable {
    let trackTitle: String
    let artistName: String
    let isPlaying: Bool
    let entries: [WidgetScheduledLineDTO]
}

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
        // Must return immediately for iOS / CarPlay Widget Gallery preview
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        if let groupEntry = loadFromAppGroup() {
            completion(groupEntry)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricsTimelineEntry>) -> Void) {
        // 1. Fast path (0ms synchronous): Read full pre-scheduled song timeline from shared App Group
        if let scheduledPayload = loadScheduledPayloadFromAppGroup(), !scheduledPayload.entries.isEmpty {
            let timelineEntries = scheduledPayload.entries.map { item in
                LyricsTimelineEntry(
                    date: item.date,
                    trackTitle: scheduledPayload.trackTitle,
                    artistName: scheduledPayload.artistName,
                    currentLine: item.currentLine,
                    nextLine: item.nextLine
                )
            }
            completion(Timeline(entries: timelineEntries, policy: .atEnd))
            return
        }

        // 2. Fallback path: Localhost HTTP server
        fetchFromLocalServer { payload in
            if let payload = payload, !payload.entries.isEmpty {
                let timelineEntries = payload.entries.map { item in
                    LyricsTimelineEntry(
                        date: item.date,
                        trackTitle: payload.trackTitle,
                        artistName: payload.artistName,
                        currentLine: item.currentLine,
                        nextLine: item.nextLine
                    )
                }
                completion(Timeline(entries: timelineEntries, policy: .atEnd))
            } else if let groupEntry = loadFromAppGroup() {
                let refreshDate = Date().addingTimeInterval(5)
                completion(Timeline(entries: [groupEntry], policy: .after(refreshDate)))
            } else {
                let fallback = LyricsTimelineEntry(
                    date: Date(),
                    trackTitle: "CarPlay Lyrics",
                    artistName: "En espera",
                    currentLine: "Abre LyricsCarPlay y reproduce tu música",
                    nextLine: "Las letras aparecerán aquí en tiempo real"
                )
                let refreshDate = Date().addingTimeInterval(15)
                completion(Timeline(entries: [fallback], policy: .after(refreshDate)))
            }
        }
    }

    private var appGroupSuites: [String] {
        let extBundleID = Bundle.main.bundleIdentifier ?? "com.antigravity.LyricsCarPlay.LyricsWidgetExtension"
        let baseBundleID = extBundleID.replacingOccurrences(of: ".LyricsWidgetExtension", with: "")
        return [
            "group.\(baseBundleID)",
            "group.com.antigravity.LyricsCarPlay.RN6X4K84VZ",
            "group.com.antigravity.LyricsCarPlay"
        ]
    }

    private func loadScheduledPayloadFromAppGroup() -> WidgetSyncPayloadDTO? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        for suite in appGroupSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let data = defaults.data(forKey: "WidgetScheduledPayloadData"),
               let decoded = try? decoder.decode(WidgetSyncPayloadDTO.self, from: data) {
                return decoded
            }
        }
        return nil
    }

    private func loadFromAppGroup() -> LyricsTimelineEntry? {
        for suite in appGroupSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let title = defaults.string(forKey: "WidgetTrackTitle"),
               let currentLine = defaults.string(forKey: "WidgetCurrentLine") {
                return LyricsTimelineEntry(
                    date: Date(),
                    trackTitle: title,
                    artistName: defaults.string(forKey: "WidgetArtistName") ?? "",
                    currentLine: currentLine,
                    nextLine: defaults.string(forKey: "WidgetNextLine") ?? ""
                )
            }
        }
        return nil
    }

    private func fetchFromLocalServer(completion: @escaping (WidgetSyncPayloadDTO?) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:49281/state") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data = data else {
                completion(nil)
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let decoded = try? decoder.decode(WidgetSyncPayloadDTO.self, from: data)
            completion(decoded)
        }.resume()
    }
}

extension View {
    @ViewBuilder
    func carPlayWidgetContainerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        } else {
            self.background(Color(UIColor.secondarySystemBackground))
        }
    }
}

struct CarPlayStaticWidgetView: View {
    let entry: LyricsTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)

            // Main active verse (large & bold, full widget space without title header)
            Text(entry.currentLine)
                .font(.system(size: family == .systemSmall ? 20 : 23, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(family == .systemSmall ? 4 : 3)
                .minimumScaleFactor(0.68)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Upcoming verse preview
            if !entry.nextLine.isEmpty {
                Text(entry.nextLine)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .carPlayWidgetContainerBackground()
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
