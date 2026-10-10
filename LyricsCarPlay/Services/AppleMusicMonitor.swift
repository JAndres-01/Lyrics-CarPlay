import Combine
import Foundation
import MediaPlayer

/// Monitor for system Apple Music playback using MPMusicPlayerController.
@MainActor
public final class AppleMusicMonitor: ObservableObject {
    @Published public private(set) var currentTrack: TrackInfo?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentPlaybackTime: TimeInterval = 0.0

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var timer: AnyCancellable?

    public init() {}

    /// Requests user authorization to access Apple Music / Media Library.
    public func requestAuthorization() async -> Bool {
        let status = await MPMediaLibrary.requestAuthorization()
        return status == .authorized
    }

    /// Starts observing Now Playing item changes.
    public func startMonitoring(onTrackChanged: @escaping (TrackInfo) -> Void, onPlaybackTimeUpdated: @escaping (TimeInterval, Bool) -> Void) {
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTrackChange(onTrackChanged: onTrackChanged)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStateChange()
            }
        }

        // Periodic timer to poll current playback time
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let time = self.player.currentPlaybackTime
                let playing = self.player.playbackState == .playing
                self.currentPlaybackTime = time
                self.isPlaying = playing
                onPlaybackTimeUpdated(time, playing)
            }

        handleTrackChange(onTrackChanged: onTrackChanged)
    }

    public func stopMonitoring() {
        player.endGeneratingPlaybackNotifications()
        timer?.cancel()
        timer = nil
    }

    private func handleTrackChange(onTrackChanged: (TrackInfo) -> Void) {
        guard let item = player.nowPlayingItem else { return }
        let title = item.title ?? "Desconocido"
        let artist = item.artist ?? "Desconocido"
        let album = item.albumTitle ?? ""
        let duration = item.playbackDuration

        let track = TrackInfo(
            id: "\(artist)-\(title)",
            title: title,
            artist: artist,
            album: album,
            duration: duration
        )

        self.currentTrack = track
        onTrackChanged(track)
    }

    private func handleStateChange() {
        self.isPlaying = player.playbackState == .playing
    }
}
