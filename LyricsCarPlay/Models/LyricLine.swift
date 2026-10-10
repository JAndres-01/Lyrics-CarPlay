import Foundation

/// Represents a single line of lyrics paired with its timestamp in seconds.
public struct LyricLine: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let text: String

    public init(id: UUID = UUID(), timestamp: TimeInterval, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Helper extension to format timestamps for debugging or UI display.
extension LyricLine {
    public var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        let hundredths = Int((timestamp.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
