import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// MARK: - 1. Live Activity Widgets (CarPlay Dashboard & Dynamic Island)

#if compiler(>=6.0)
@available(iOSApplicationExtension 18.0, *)
struct LyricsLiveActivityWidget18: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            CarPlayLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandViews.expandedView(context: context)
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } minimal: {
                EmptyView()
            }
        }
        .contentMarginsDisabled()
        .supplementalActivityFamilies([.small])
    }
}
#endif

struct LyricsLiveActivityWidgetLegacy: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            CarPlayLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandViews.expandedView(context: context)
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } minimal: {
                EmptyView()
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
        // Fast path for Widget Gallery and CarPlay dashboard preview
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
        let now = Date()

        // 1. Fast path (0ms synchronous): Read pre-scheduled song timeline from shared App Group
        if let scheduledPayload = loadScheduledPayloadFromAppGroup(), !scheduledPayload.entries.isEmpty {
            let upcoming = scheduledPayload.entries.filter { $0.date > now }
            var timelineEntries: [LyricsTimelineEntry] = []

            // If we have an instantaneous active line in UserDefaults, use it as the first entry at now
            if let groupEntry = loadFromAppGroup() {
                timelineEntries.append(groupEntry)
            }

            // Append future scheduled entries for the rest of the song
            for item in upcoming {
                timelineEntries.append(
                    LyricsTimelineEntry(
                        date: item.date,
                        trackTitle: scheduledPayload.trackTitle,
                        artistName: scheduledPayload.artistName,
                        currentLine: item.currentLine,
                        nextLine: item.nextLine
                    )
                )
            }

            if !timelineEntries.isEmpty {
                completion(Timeline(entries: timelineEntries, policy: .atEnd))
                return
            }
        }

        // 2. Fallback: single active line from App Group
        if let groupEntry = loadFromAppGroup() {
            completion(Timeline(entries: [groupEntry], policy: .atEnd))
            return
        }

        // 3. Fallback path: Localhost HTTP server
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
                completion(Timeline(entries: [groupEntry], policy: .atEnd))
            } else {
                let fallback = LyricsTimelineEntry(
                    date: Date(),
                    trackTitle: "CarPlay Lyrics",
                    artistName: "En espera",
                    currentLine: "Abre LyricsCarPlay y reproduce tu música",
                    nextLine: "Las letras aparecerán aquí en tiempo real"
                )
                completion(Timeline(entries: [fallback], policy: .atEnd))
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

// MARK: - Backward-compatible Container Background Helper

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

            // Main active verse (large & bold, 100% lyrics without title header)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .carPlayWidgetContainerBackground()
    }
}

#if compiler(>=5.9)
@available(iOSApplicationExtension 17.0, *)
struct LyricsCarPlayStandbyWidget17: Widget {
    let kind: String = "LyricsCarPlayStandbyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricsTimelineProvider()) { entry in
            CarPlayStaticWidgetView(entry: entry)
        }
        .configurationDisplayName("CarPlay Lyrics")
        .description("Muestra la letra sincronizada en grande en la pantalla de Widgets de CarPlay.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
#endif

struct LyricsCarPlayStandbyWidgetLegacy: Widget {
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

// MARK: - Main Widget Bundle Launcher

#if compiler(>=6.0)
@available(iOSApplicationExtension 18.0, *)
struct LyricsWidgetBundle18: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivityWidget18()
        LyricsCarPlayStandbyWidget17()
    }
}
#endif

#if compiler(>=5.9)
@available(iOSApplicationExtension 17.0, *)
struct LyricsWidgetBundle17: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivityWidgetLegacy()
        LyricsCarPlayStandbyWidget17()
    }
}
#endif

struct LyricsWidgetBundleLegacy: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivityWidgetLegacy()
        LyricsCarPlayStandbyWidgetLegacy()
    }
}

@main
struct LyricsWidgetLauncher {
    static func main() {
        #if compiler(>=6.0)
        if #available(iOSApplicationExtension 18.0, *) {
            LyricsWidgetBundle18.main()
            return
        }
        #endif

        #if compiler(>=5.9)
        if #available(iOSApplicationExtension 17.0, *) {
            LyricsWidgetBundle17.main()
            return
        }
        #endif

        LyricsWidgetBundleLegacy.main()
    }
}
