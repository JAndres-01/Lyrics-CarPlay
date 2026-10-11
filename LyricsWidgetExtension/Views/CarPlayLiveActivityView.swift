import ActivityKit
import SwiftUI
import WidgetKit

/// Optimized Live Activity View rendered on CarPlay Dashboard, CarPlay notifications, and Lock Screen.
/// Dedicated 100% to synchronized lyrics with instantaneous updates, high contrast, and zero compositor lag.
public struct CarPlayLiveActivityView: View {
    let context: ActivityViewContext<LyricsAttributes>

    public init(context: ActivityViewContext<LyricsAttributes>) {
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Spacer(minLength: 0)

            // Large active lyric line (100% lyrics, clean & bold, instant update without heavy transitions)
            Text(context.state.currentLine)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.70)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Upcoming lyric line preview
            if !context.state.nextLine.isEmpty {
                Text(context.state.nextLine)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground).opacity(0.96))
    }
}
