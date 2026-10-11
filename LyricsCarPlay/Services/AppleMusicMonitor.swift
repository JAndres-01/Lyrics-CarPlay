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
    private var timer: DispatchSourceTimer?

    public init() {}

    deinit {
        timer?.cancel()
    }

    /// Requests user authorization to access Apple Music / Media Library.
    public func requestAuthorization() async -> Bool {
        let status = await MPMediaLibrary.requestAuthorization()
        return status == .authorized
    }

    /// Returns the instantaneous playback time and playing state from the native system music player.
    public func getCurrentPlaybackSnapshot() -> (time: TimeInterval, isPlaying: Bool) {
        let time = player.currentPlaybackTime.isNormal ? player.currentPlaybackTime : 0.0
        let playing = player.playbackState == .playing
        return (time, playing)
    }

    /// Starts observing Now Playing item changes with high-frequency background-safe polling (0.15s).
    public func startMonitoring(
        onTrackChanged: @escaping (TrackInfo) -> Void,
        onPlaybackTimeUpdated: @escaping (TimeInterval, Bool) -> Void
    ) {
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
                guard let self = self else { return }
                self.handleStateChange()
                let snapshot = self.getCurrentPlaybackSnapshot()
                onPlaybackTimeUpdated(snapshot.time, snapshot.isPlaying)
            }
        }

        // High-frequency DispatchSourceTimer (0.15s) to keep anchor time locked to hardware audio clock even in background
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now(), repeating: .milliseconds(150), leeway: .milliseconds(20))
        t.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let snapshot = self.getCurrentPlaybackSnapshot()
                self.currentPlaybackTime = snapshot.time
                self.isPlaying = snapshot.isPlaying
                onPlaybackTimeUpdated(snapshot.time, snapshot.isPlaying)
            }
        }
        t.resume()
        self.timer = t

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

        if self.currentTrack?.id != track.id {
            self.currentTrack = track
            onTrackChanged(track)
        }
    }

    private func handleStateChange() {
        self.isPlaying = player.playbackState == .playing
    }
}
