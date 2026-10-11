import ActivityKit
import SwiftUI
import WidgetKit

/// Optimized Live Activity View rendered on CarPlay Dashboard, CarPlay notifications, and Lock Screen.
/// Includes smooth vertical sliding transition when lyrics change.
public struct CarPlayLiveActivityView: View {
    let context: ActivityViewContext<LyricsAttributes>

    public init(context: ActivityViewContext<LyricsAttributes>) {
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Track Title & Artist header
            HStack(spacing: 6) {
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

            // High contrast current lyric line with fluid vertical slide animation
            ZStack(alignment: .leading) {
                Text(context.state.currentLine)
                    .id("current-" + context.state.currentLine)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: context.state.currentLine)

            // Next lyric line preview with smooth transition
            if !context.state.nextLine.isEmpty {
                ZStack(alignment: .leading) {
                    Text(context.state.nextLine)
                        .id("next-" + context.state.nextLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: context.state.nextLine)
            }
        }
        .padding(14)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
}
