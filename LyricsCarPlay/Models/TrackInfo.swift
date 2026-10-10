import Foundation

/// Represents metadata for the song currently playing on the device or mock player.
public struct TrackInfo: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let artworkURL: URL?

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String = "",
        duration: TimeInterval,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }

    public static let mock = TrackInfo(
        id: "mock-bohemian-rhapsody",
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        duration: 354.0,
        artworkURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/9/9f/A_Night_at_the_Opera_%28Queen_album%29.png")
    )
}
