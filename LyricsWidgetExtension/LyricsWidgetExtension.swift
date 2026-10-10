import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LyricsWidgetExtension: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            // CarPlay Dashboard / Lock Screen Banner View
            CarPlayLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandViews.expandedView(context: context)
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            } minimal: {
                Image(systemName: "text.quote")
                    .foregroundColor(.accentColor)
            }
        }
    }
}
