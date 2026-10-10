import Combine
import Foundation

/// Spotify Currently Playing response DTO
public struct SpotifyCurrentlyPlayingResponse: Codable {
    public struct Item: Codable {
        public struct Artist: Codable {
            public let name: String
        }
        public struct Album: Codable {
            public struct Image: Codable {
                public let url: String
            }
            public let name: String
            public let images: [Image]?
        }
        public let id: String
        public let name: String
        public let duration_ms: Int
        public let artists: [Artist]
        public let album: Album
    }
    public let item: Item?
    public let progress_ms: Int?
    public let is_playing: Bool?
}

/// Spotify API Monitor to track song metadata & progress via Spotify Web API.
@MainActor
public final class SpotifyMonitor: ObservableObject {
    @Published public private(set) var currentTrack: TrackInfo?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentPlaybackTime: TimeInterval = 0.0
    @Published public var accessToken: String?

    private var pollingTimer: AnyCancellable?

    public init() {}

    /// Starts polling Spotify Currently Playing API if access token is available.
    public func startPolling(
        token: String,
        onTrackChanged: @escaping (TrackInfo) -> Void,
        onPlaybackTimeUpdated: @escaping (TimeInterval, Bool) -> Void
    ) {
        self.accessToken = token
        stopPolling()

        pollingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchCurrentlyPlaying(onTrackChanged: onTrackChanged, onPlaybackTimeUpdated: onPlaybackTimeUpdated)
                }
            }
    }

    public func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    private func fetchCurrentlyPlaying(
        onTrackChanged: (TrackInfo) -> Void,
        onPlaybackTimeUpdated: (TimeInterval, Bool) -> Void
    ) async {
        guard let token = accessToken, !token.isEmpty,
              let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            let decoded = try JSONDecoder().decode(SpotifyCurrentlyPlayingResponse.self, from: data)
            guard let item = decoded.item else { return }

            let title = item.name
            let artist = item.artists.first?.name ?? "Desconocido"
            let album = item.album.name
            let duration = Double(item.duration_ms) / 1000.0
            let progress = Double(decoded.progress_ms ?? 0) / 1000.0
            let playing = decoded.is_playing ?? false

            let artworkURL = item.album.images?.first.flatMap { URL(string: $0.url) }

            let track = TrackInfo(
                id: item.id,
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                artworkURL: artworkURL
            )

            if self.currentTrack?.id != track.id {
                self.currentTrack = track
                onTrackChanged(track)
            }

            self.currentPlaybackTime = progress
            self.isPlaying = playing
            onPlaybackTimeUpdated(progress, playing)

        } catch {
            print("Spotify API Error: \(error.localizedDescription)")
        }
    }
}
