import ActivityKit
import SwiftUI
import WidgetKit

/// Optimized Live Activity View rendered on CarPlay Dashboard, CarPlay notifications, and Lock Screen.
/// Features clean header without music icon, large active lyric text, and scale-up sliding transition.
public struct CarPlayLiveActivityView: View {
    let context: ActivityViewContext<LyricsAttributes>

    public init(context: ActivityViewContext<LyricsAttributes>) {
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clean Track Title & Artist header (No music note icon)
            HStack(spacing: 4) {
                Text(context.state.trackTitle)
                    .font(.caption.bold())
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)

                Text("• \(context.state.artistName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            // Large active lyric line that grows in size while sliding up from the bottom
            ZStack(alignment: .leading) {
                Text(context.state.currentLine)
                    .id("active-" + context.state.currentLine)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.72, anchor: .bottomLeading)
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.90, anchor: .topLeading)
                                .combined(with: .move(edge: .top))
                                .combined(with: .opacity)
                        )
                    )
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: context.state.currentLine)

            // Upcoming lyric line preview (smaller, ready to rise and grow next)
            if !context.state.nextLine.isEmpty {
                ZStack(alignment: .leading) {
                    Text(context.state.nextLine)
                        .id("upcoming-" + context.state.nextLine)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .scale(scale: 1.25, anchor: .topLeading)
                                    .combined(with: .move(edge: .top))
                                    .combined(with: .opacity)
                            )
                        )
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: context.state.nextLine)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemBackground).opacity(0.96))
    }
}
