import ActivityKit
import SwiftUI
import WidgetKit

/// Dynamic Island view layouts (Minimal, CompactLeading, CompactTrailing, Expanded).
public struct DynamicIslandViews {
    
    // Expanded view when user long presses Dynamic Island
    public static func expandedView(context: ActivityViewContext<LyricsAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedContent {
            DynamicIslandExpandedRegion(.leading) {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundColor(.accentColor)
                    Text(context.state.trackTitle)
                        .font(.caption.bold())
                        .lineLimit(1)
                }
            }
            
            DynamicIslandExpandedRegion(.trailing) {
                Text(context.state.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            DynamicIslandExpandedRegion(.bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.currentLine)
                        .font(.body.bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !context.state.nextLine.isEmpty {
                        Text(context.state.nextLine)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
