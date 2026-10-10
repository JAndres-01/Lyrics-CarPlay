import Combine
import Foundation
import SwiftUI

public enum MusicSource: String, CaseIterable, Identifiable {
    case mock = "Simulación (Mock)"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"

    public var id: String { rawValue }
}

@MainActor
public final class MainViewModel: ObservableObject {
    @Published public var selectedSource: MusicSource = .mock
    @Published public var currentTrack: TrackInfo = TrackInfo.mock
    @Published public var syncState: SyncState?
    @Published public var lyrics: [LyricLine] = []
    @Published public var isLoadingLyrics: Bool = false
    @Published public var errorMessage: String?
    @Published public var spotifyToken: String = ""

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
    public let spotifyMonitor = SpotifyMonitor()
    private let lrclibService = LRCLIBService()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupBindings()
    }

    private func setupBindings() {
        syncEngine.$currentSyncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, let state = state else { return }
                self.syncState = state
                if #available(iOS 16.2, *) {
                    if self.liveActivityManager.isActivityActive {
                        self.liveActivityManager.updateActivity(
                            track: self.currentTrack,
                            syncState: state,
                            isPlaying: self.syncEngine.isPlaying
                        )
                    }
                }
            }
            .store(in: &cancellables)
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

            // Set up sync engine
            syncEngine.setLyrics(fetchedLyrics, track: track)

            // Start Live Activity
            if #available(iOS 16.2, *) {
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
        [00:00.00] 🎵 (Intro Instrumental)
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
        
        if #available(iOS 16.2, *) {
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
        syncEngine.stopMockTimer()
        appleMusicMonitor.stopMonitoring()
        spotifyMonitor.stopPolling()
        if #available(iOS 16.2, *) {
            liveActivityManager.endActivity()
        }
    }
}
