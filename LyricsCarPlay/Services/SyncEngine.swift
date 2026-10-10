import Combine
import Foundation

public struct SyncState {
    public let currentLine: String
    public let nextLine: String
    public let previousLine: String
    public let currentIndex: Int
    public let progress: Double
}

/// High-precision synchronization engine that pairs playback time with LRC lines.
@MainActor
public final class SyncEngine: ObservableObject {
    @Published public private(set) var currentSyncState: SyncState?
    @Published public private(set) var lyrics: [LyricLine] = []
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0.0

    private var timer: AnyCancellable?
    private var trackInfo: TrackInfo?
    private var onLineChanged: ((SyncState) -> Void)?

    public init() {}

    /// Configures the engine with new lyrics and track info.
    public func setLyrics(_ newLyrics: [LyricLine], track: TrackInfo, onLineChanged: ((SyncState) -> Void)? = nil) {
        self.lyrics = newLyrics
        self.trackInfo = track
        self.onLineChanged = onLineChanged
        self.currentTime = 0.0
        updateSyncState(for: 0.0)
    }

    /// Updates current playback position (e.g. from MPMusicPlayerController or Spotify).
    public func updatePlaybackTime(_ time: TimeInterval, isPlaying: Bool) {
        self.currentTime = time
        self.isPlaying = isPlaying
        updateSyncState(for: time)
    }

    /// Internal calculation of active lyric line based on current timestamp.
    private func updateSyncState(for time: TimeInterval) {
        guard !lyrics.isEmpty else {
            currentSyncState = nil
            return
        }

        // Find the latest line whose timestamp is <= current time
        var activeIndex = -1
        for (index, line) in lyrics.enumerated() {
            if line.timestamp <= time {
                activeIndex = index
            } else {
                break
            }
        }

        let currentText = activeIndex >= 0 ? lyrics[activeIndex].text : "🎵 ..."
        let previousText = activeIndex > 0 ? lyrics[activeIndex - 1].text : ""
        let nextText = (activeIndex >= 0 && activeIndex + 1 < lyrics.count) ? lyrics[activeIndex + 1].text : ""

        let duration = trackInfo?.duration ?? 1.0
        let progress = min(max(time / duration, 0.0), 1.0)

        let newState = SyncState(
            currentLine: currentText,
            nextLine: nextText,
            previousLine: previousText,
            currentIndex: activeIndex,
            progress: progress
        )

        // Only emit if line changed or progress updated
        if currentSyncState?.currentLine != newState.currentLine || currentSyncState?.currentIndex != newState.currentIndex {
            self.currentSyncState = newState
            onLineChanged?(newState)
        } else {
            self.currentSyncState = newState
        }
    }

    /// Starts a local high-frequency timer for Mock Player testing.
    public func startMockTimer(speedMultiplier: Double = 1.0) {
        stopMockTimer()
        isPlaying = true
        
        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                let newTime = self.currentTime + (0.25 * speedMultiplier)
                let duration = self.trackInfo?.duration ?? 300.0
                if newTime >= duration {
                    self.stopMockTimer()
                    self.updatePlaybackTime(0.0, isPlaying: false)
                } else {
                    self.updatePlaybackTime(newTime, isPlaying: true)
                }
            }
    }

    public func stopMockTimer() {
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
}
