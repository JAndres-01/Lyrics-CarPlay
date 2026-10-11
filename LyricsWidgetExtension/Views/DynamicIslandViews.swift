import ActivityKit
import SwiftUI
import WidgetKit

/// Dynamic Island view layouts (Minimal, CompactLeading, CompactTrailing, Expanded).
public struct DynamicIslandViews {

    @DynamicIslandExpandedContentBuilder
    public static func expandedView(context: ActivityViewContext<LyricsAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.currentLine)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !context.state.nextLine.isEmpty {
                    Text(context.state.nextLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 2)
        }
    }
}
