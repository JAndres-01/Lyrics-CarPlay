import ActivityKit
import Foundation

/// Shared ActivityAttributes definition for WidgetKit / ActivityKit.
/// Used to update Live Activity cards on CarPlay, Dynamic Island, and Lock Screen.
public struct LyricsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentLine: String
        public var nextLine: String
        public var previousLine: String
        public var trackTitle: String
        public var artistName: String
        public var progress: Double // 0.0 to 1.0
        public var isPlaying: Bool

        public init(
            currentLine: String,
            nextLine: String = "",
            previousLine: String = "",
            trackTitle: String,
            artistName: String,
            progress: Double = 0.0,
            isPlaying: Bool = true
        ) {
            self.currentLine = currentLine
            self.nextLine = nextLine
            self.previousLine = previousLine
            self.trackTitle = trackTitle
            self.artistName = artistName
            self.progress = progress
            self.isPlaying = isPlaying
        }
    }

    public var trackId: String

    public init(trackId: String) {
        self.trackId = trackId
    }
}
