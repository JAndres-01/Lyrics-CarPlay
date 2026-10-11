import Combine
import Foundation

public struct SyncState: Equatable {
    public let currentLine: String
    public let nextLine: String
    public let previousLine: String
    public let currentIndex: Int
    public let progress: Double
}

/// High-precision synchronization engine with real-time 60ms interpolation and adjustable lookahead offset.
@MainActor
public final class SyncEngine: ObservableObject {
    @Published public private(set) var currentSyncState: SyncState?
    @Published public private(set) var lyrics: [LyricLine] = []
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0.0
    /// Increments only when the full song schedule changes (new song, seek/drift, play/pause, or offset adjustment).
    @Published public private(set) var timelineRevision: Int = 0

    /// Lookahead offset in seconds (positive = lyrics appear earlier to compensate audio/UI lag).
    /// Default is +0.85s which matches human reading anticipation and animation duration.
    @Published public var lyricOffset: TimeInterval = 0.85 {
        didSet {
            UserDefaults.standard.set(lyricOffset, forKey: "LyricTimeOffset")
            updateSyncState(for: interpolatedCurrentTime(), forceEmit: true)
            timelineRevision &+= 1
        }
    }

    private var timer: AnyCancellable?
    private var interpolationTimer: AnyCancellable?
    private var trackInfo: TrackInfo?
    private var onLineChanged: ((SyncState) -> Void)?

    // Anchor points for smooth sub-100ms time interpolation between external polls
    private var anchorPlaybackTime: TimeInterval = 0.0
    private var anchorWallTime: Date = Date()

    public init() {
        if UserDefaults.standard.object(forKey: "LyricTimeOffset") != nil {
            self.lyricOffset = UserDefaults.standard.double(forKey: "LyricTimeOffset")
        }
        startInterpolationClock()
    }

    /// Configures the engine with new lyrics and track info.
    public func setLyrics(
        _ newLyrics: [LyricLine],
        track: TrackInfo,
        initialTime: TimeInterval = 0.0,
        isPlaying: Bool = true,
        onLineChanged: ((SyncState) -> Void)? = nil
    ) {
        self.lyrics = newLyrics
        self.trackInfo = track
        self.onLineChanged = onLineChanged
        self.anchorPlaybackTime = initialTime
        self.anchorWallTime = Date()
        self.currentTime = initialTime
        self.isPlaying = isPlaying
        self.currentSyncState = nil
        updateSyncState(for: initialTime, forceEmit: true)
        timelineRevision &+= 1
    }

    /// Updates current playback position from Apple Music or Spotify.
    public func updatePlaybackTime(_ time: TimeInterval, isPlaying: Bool) {
        let currentInterpolated = interpolatedCurrentTime()
        let timeDrift = abs(time - currentInterpolated)
        let playStateChanged = (self.isPlaying != isPlaying)

        self.anchorPlaybackTime = time
        self.anchorWallTime = Date()
        self.currentTime = time
        self.isPlaying = isPlaying
        updateSyncState(for: time)

        // Only reschedule the WidgetKit timeline if user paused/resumed or scrubbed/drifted > 0.75s
        if playStateChanged || timeDrift > 0.75 {
            timelineRevision &+= 1
        }
    }

    /// Calculates the exact current playback time using wall-clock delta since the last poll.
    private func interpolatedCurrentTime() -> TimeInterval {
        guard isPlaying else { return anchorPlaybackTime }
        let elapsed = Date().timeIntervalSince(anchorWallTime)
        return anchorPlaybackTime + elapsed
    }

    /// High-frequency (60ms / ~16Hz) local clock that triggers lyric line transitions at the exact millisecond.
    private func startInterpolationClock() {
        interpolationTimer?.cancel()
        interpolationTimer = Timer.publish(every: 0.06, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying, !self.lyrics.isEmpty else { return }
                let exactTime = self.interpolatedCurrentTime()
                self.currentTime = exactTime
                self.updateSyncState(for: exactTime)
            }
    }

    /// Internal calculation of active lyric line based on current timestamp + lookahead offset.
    private func updateSyncState(for rawTime: TimeInterval, forceEmit: Bool = false) {
        guard !lyrics.isEmpty else {
            currentSyncState = nil
            return
        }

        // Apply lookahead offset so the animation starts right before/as the artist sings
        let effectiveTime = max(0.0, rawTime + lyricOffset)

        // Binary/linear search for the latest line whose timestamp <= effectiveTime
        var activeIndex = -1
        for (index, line) in lyrics.enumerated() {
            if line.timestamp <= effectiveTime {
                activeIndex = index
            } else {
                break
            }
        }

        let currentText = activeIndex >= 0 ? lyrics[activeIndex].text : "..."
        let previousText = activeIndex > 0 ? lyrics[activeIndex - 1].text : ""
        let nextText = (activeIndex >= 0 && activeIndex + 1 < lyrics.count) ? lyrics[activeIndex + 1].text : (lyrics.first?.text ?? "")

        let duration = max(trackInfo?.duration ?? 1.0, 1.0)
        let progress = min(max(rawTime / duration, 0.0), 1.0)

        // CRITICAL: Only publish and trigger Live Activity / UI scroll when the active line actually changes!
        if forceEmit || currentSyncState?.currentIndex != activeIndex || currentSyncState?.currentLine != currentText {
            let newState = SyncState(
                currentLine: currentText,
                nextLine: nextText,
                previousLine: previousText,
                currentIndex: activeIndex,
                progress: progress
            )
            self.currentSyncState = newState
            onLineChanged?(newState)
        }
    }

    /// Starts a local timer for Mock Player testing.
    public func startMockTimer(speedMultiplier: Double = 1.0) {
        stopMockTimer(notifyTimeline: false)
        anchorPlaybackTime = currentTime
        anchorWallTime = Date()
        isPlaying = true
        timelineRevision &+= 1

        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                let duration = self.trackInfo?.duration ?? 300.0
                if self.currentTime >= duration {
                    self.stopMockTimer()
                    self.updatePlaybackTime(0.0, isPlaying: false)
                }
            }
    }

    public func stopMockTimer(notifyTimeline: Bool = true) {
        let wasPlaying = isPlaying
        isPlaying = false
        anchorPlaybackTime = currentTime
        timer?.cancel()
        timer = nil
        if notifyTimeline && wasPlaying {
            timelineRevision &+= 1
        }
    }
}
