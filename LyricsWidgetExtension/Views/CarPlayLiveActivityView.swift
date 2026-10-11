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
        VStack(alignment: .leading, spacing: 6) {
            // Large active lyric line that grows in size while sliding up from the bottom
            ZStack(alignment: .leading) {
                Text(context.state.currentLine)
                    .id("active-" + context.state.currentLine)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(UIColor.systemBackground).opacity(0.96))
    }
}
