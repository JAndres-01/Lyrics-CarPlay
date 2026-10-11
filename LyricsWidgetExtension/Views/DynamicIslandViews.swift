import ActivityKit
import SwiftUI
import WidgetKit

/// Dynamic Island view layouts (Minimal, CompactLeading, CompactTrailing, Expanded).
public struct DynamicIslandViews {

    @DynamicIslandExpandedContentBuilder
    public static func expandedView(context: ActivityViewContext<LyricsAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.leading) {
            Text(context.state.trackTitle)
                .font(.caption.bold())
                .lineLimit(1)
        }

        DynamicIslandExpandedRegion(.trailing) {
            Text(context.state.artistName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }

        DynamicIslandExpandedRegion(.bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.currentLine)
                    .id("di-active-" + context.state.currentLine)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.75, anchor: .bottomLeading)
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )

                if !context.state.nextLine.isEmpty {
                    Text(context.state.nextLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: context.state.currentLine)
            .padding(.top, 4)
        }
    }
}
