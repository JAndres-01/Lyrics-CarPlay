import Combine
import Foundation
import SwiftUI
import WidgetKit

public enum MusicSource: String, CaseIterable, Identifiable {
    case mock = "Simulación (Mock)"
    case spotify = "Spotify"
    case appleMusic = "Apple Music"

    public var id: String { rawValue }
}

@MainActor
public final class MainViewModel: ObservableObject {
    @Published public var selectedSource: MusicSource = .mock {
        didSet {
            handleSourceChanged(selectedSource)
        }
    }
    @Published public var currentTrack: TrackInfo = TrackInfo.mock
    @Published public var syncState: SyncState?
    @Published public var lyrics: [LyricLine] = []
    @Published public var isLoadingLyrics: Bool = false
    @Published public var errorMessage: String?
    @Published public var lyricOffset: TimeInterval = 0.85
    @Published public var isLiveActivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isLiveActivityEnabled, forKey: "LiveActivityEnabled")
            if #available(iOS 16.2, *) {
                if isLiveActivityEnabled {
                    if let state = syncState {
                        liveActivityManager.startActivity(track: currentTrack, initialSyncState: state)
                    }
                } else {
                    liveActivityManager.endActivity()
                }
            }
        }
    }

    public let syncEngine = SyncEngine()

    private var _liveActivityManager: Any?
    @available(iOS 16.2, *)
    public var liveActivityManager: LiveActivityManager {
        if _liveActivityManager == nil {
            _liveActivityManager = LiveActivityManager()
        }
        return _liveActivityManager as! LiveActivityManager
    }

    public let appleMusicMonitor = AppleMusicMonitor()
    public var spotifyMonitor = SpotifyMonitor()
    private let lrclibService = LRCLIBService()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.lyricOffset = syncEngine.lyricOffset
        if UserDefaults.standard.object(forKey: "LiveActivityEnabled") != nil {
            self.isLiveActivityEnabled = UserDefaults.standard.bool(forKey: "LiveActivityEnabled")
        }
        LocalWidgetServer.shared.start()
        setupBindings()
    }

    public func adjustOffset(by delta: TimeInterval) {
        let rounded = ((lyricOffset + delta) * 10).rounded() / 10
        self.lyricOffset = rounded
        self.syncEngine.lyricOffset = rounded
    }

    private func updateStandbyWidget(track: TrackInfo, state: SyncState) {
        let appBundleID = Bundle.main.bundleIdentifier ?? "com.antigravity.LyricsCarPlay"
        let suiteCandidates = [
            "group.\(appBundleID)",
            "group.com.antigravity.LyricsCarPlay.RN6X4K84VZ",
            "group.com.antigravity.LyricsCarPlay"
        ]
        for suite in suiteCandidates {
            if let defaults = UserDefaults(suiteName: suite) {
                defaults.set(track.title, forKey: "WidgetTrackTitle")
                defaults.set(track.artist, forKey: "WidgetArtistName")
                defaults.set(state.currentLine, forKey: "WidgetCurrentLine")
                defaults.set(state.nextLine, forKey: "WidgetNextLine")
            }
        }

        let now = Date()
        var entries: [WidgetScheduledLine] = [
            WidgetScheduledLine(date: now, currentLine: state.currentLine, nextLine: state.nextLine)
        ]

        if syncEngine.isPlaying && !lyrics.isEmpty {
            let effectiveTime = syncEngine.currentTime + syncEngine.lyricOffset
            let startIdx = max(0, state.currentIndex + 1)
            if startIdx < lyrics.count {
                let endIdx = min(lyrics.count, startIdx + 40)
                for idx in startIdx..<endIdx {
                    let line = lyrics[idx]
                    let nextText = (idx + 1 < lyrics.count) ? lyrics[idx + 1].text : ""
                    let delay = line.timestamp - effectiveTime
                    if delay > 0.05 {
                        entries.append(
                            WidgetScheduledLine(
                                date: now.addingTimeInterval(delay),
                                currentLine: line.text,
                                nextLine: nextText
                            )
                        )
                    }
                }
            }
        }

        let payload = WidgetSyncPayload(
            trackTitle: track.title,
            artistName: track.artist,
            isPlaying: syncEngine.isPlaying,
            entries: entries
        )
        LocalWidgetServer.shared.updatePayload(payload)

        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func setupBindings() {
        syncEngine.$currentSyncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, let state = state else { return }
                self.syncState = state
                self.updateStandbyWidget(track: self.currentTrack, state: state)

                if #available(iOS 16.2, *) {
                    if self.isLiveActivityEnabled {
                        if self.liveActivityManager.isActivityActive {
                            self.liveActivityManager.updateActivity(
                                track: self.currentTrack,
                                syncState: state,
                                isPlaying: self.syncEngine.isPlaying
                            )
                        } else {
                            self.liveActivityManager.startActivity(
                                track: self.currentTrack,
                                initialSyncState: state
                            )
                            if let err = self.liveActivityManager.lastErrorMessage {
                                self.errorMessage = err
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Observe Spotify connection status to start polling automatically
        spotifyMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                if connected && self.selectedSource == .spotify {
                    self.startSpotifyMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    public func handleSourceChanged(_ source: MusicSource) {
        stopAllMonitors()

        switch source {
        case .mock:
            self.currentTrack = TrackInfo.mock
        case .spotify:
            if spotifyMonitor.isConnected {
                startSpotifyMonitoring()
            }
        case .appleMusic:
            startAppleMusicMonitoring()
        }
    }

    private func stopAllMonitors() {
        syncEngine.stopMockTimer()
        spotifyMonitor.stopPolling()
        appleMusicMonitor.stopMonitoring()
    }

    public func startSpotifyMonitoring() {
        guard spotifyMonitor.isConnected else { return }
        
        spotifyMonitor.startPolling(
            onTrackChanged: { [weak self] track in
                Task { [weak self] in
                    await self?.loadLyricsAndStart(for: track)
                }
            },
            onPlaybackTimeUpdated: { [weak self] time, isPlaying in
                self?.syncEngine.updatePlaybackTime(time, isPlaying: isPlaying)
            }
        )
    }

    public func startAppleMusicMonitoring() {
        Task {
            let authorized = await appleMusicMonitor.requestAuthorization()
            guard authorized else {
                self.errorMessage = "Permiso denegado para Apple Music. Habilítalo en Ajustes."
                return
            }

            appleMusicMonitor.startMonitoring(
                onTrackChanged: { [weak self] track in
                    Task { [weak self] in
                        await self?.loadLyricsAndStart(for: track)
                    }
                },
                onPlaybackTimeUpdated: { [weak self] time, isPlaying in
                    self?.syncEngine.updatePlaybackTime(time, isPlaying: isPlaying)
                }
            )
        }
    }

    /// Loads lyrics for the selected track and starts synchronization.
    public func loadLyricsAndStart(for track: TrackInfo) async {
        self.currentTrack = track
        self.isLoadingLyrics = true
        self.errorMessage = nil

        do {
            let fetchedLyrics = try await lrclibService.fetchSyncedLyrics(
                trackName: track.title,
                artistName: track.artist,
                albumName: track.album,
                duration: track.duration
            )

            self.lyrics = fetchedLyrics
            self.isLoadingLyrics = false

            // Determine exact instantaneous playback time right after network fetch completes
            var startTime: TimeInterval = 0.0
            var playingState: Bool = true
            switch selectedSource {
            case .appleMusic:
                let snapshot = appleMusicMonitor.getCurrentPlaybackSnapshot()
                startTime = snapshot.time
                playingState = snapshot.isPlaying
            case .spotify:
                startTime = spotifyMonitor.currentPlaybackTime
                playingState = spotifyMonitor.isPlaying
            case .mock:
                startTime = 0.0
                playingState = true
            }

            // Set up sync engine at the exact current playback second
            syncEngine.setLyrics(fetchedLyrics, track: track, initialTime: startTime, isPlaying: playingState)

            // Start Live Activity if enabled
            if #available(iOS 16.2, *), isLiveActivityEnabled {
                if let initialState = syncEngine.currentSyncState {
                    liveActivityManager.startActivity(track: track, initialSyncState: initialState)
                }
            }

            // If in mock mode, start playback timer automatically
            if selectedSource == .mock {
                syncEngine.startMockTimer()
            }

        } catch {
            self.isLoadingLyrics = false
            self.errorMessage = error.localizedDescription
            
            // Fallback for mock mode demo if offline or song not found
            if selectedSource == .mock {
                loadFallbackMockLyrics(for: track)
            }
        }
    }

    /// Sample lyrics fallback for instant offline testing of Bohemian Rhapsody.
    private func loadFallbackMockLyrics(for track: TrackInfo) {
        let rawMockLRC = """
        [00:00.00] (Intro Instrumental)
        [00:15.50] Is this the real life? Is this just fantasy?
        [00:24.00] Caught in a landslide, no escape from reality
        [00:32.00] Open your eyes, look up to the skies and see
        [00:41.00] I'm just a poor boy, I need no sympathy
        [00:49.00] Because I'm easy come, easy go, little high, little low
        [00:57.00] Any way the wind blows doesn't really matter to me, to me
        [01:09.00] Mama, just killed a man
        [01:15.00] Put a gun against his head, pulled my trigger, now he's dead
        [01:25.00] Mama, life had just begun
        [01:31.00] But now I've gone and thrown it all away
        [01:39.00] Mama, ooh, didn't mean to make you cry
        [01:46.00] If I'm not back again this time tomorrow
        [01:51.00] Carry on, carry on as if nothing really matters
        """
        
        let parsed = LRCParser.parse(rawMockLRC)
        self.lyrics = parsed
        self.errorMessage = nil
        syncEngine.setLyrics(parsed, track: track)
        
        if #available(iOS 16.2, *), isLiveActivityEnabled {
            if let initialState = syncEngine.currentSyncState {
                liveActivityManager.startActivity(track: track, initialSyncState: initialState)
            }
        }
        syncEngine.startMockTimer()
    }

    /// Toggles play/pause for mock player or active music service.
    public func togglePlayPause() {
        if syncEngine.isPlaying {
            syncEngine.stopMockTimer()
        } else {
            syncEngine.startMockTimer()
        }
    }

    /// Stops tracking and closes Live Activity.
    public func stop() {
        stopAllMonitors()
        if #available(iOS 16.2, *) {
            liveActivityManager.endActivity()
        }
    }
}
