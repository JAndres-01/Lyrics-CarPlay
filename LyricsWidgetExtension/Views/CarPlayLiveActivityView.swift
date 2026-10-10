import ActivityKit
import SwiftUI
import WidgetKit

/// Optimized Live Activity View rendered on CarPlay Dashboard, CarPlay notifications, and Lock Screen.
public struct CarPlayLiveActivityView: View {
    let context: ActivityViewContext<LyricsAttributes>

    public init(context: ActivityViewContext<LyricsAttributes>) {
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Track Title & Artist header
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
                Text(context.state.trackTitle)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("• \(context.state.artistName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            // High contrast current lyric line (Primary CarPlay focus)
            Text(context.state.currentLine)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            // Next lyric line preview
            if !context.state.nextLine.isEmpty {
                Text(context.state.nextLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
}
