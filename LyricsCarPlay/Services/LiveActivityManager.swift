import ActivityKit
import Foundation

/// Controller managing the lifecycle of Live Activities (ActivityKit) for CarPlay & Dynamic Island.
/// Reuses a single persistent Activity instance so iOS never stacks notifications or hits background request errors.
@MainActor
@available(iOS 16.2, *)
public final class LiveActivityManager: ObservableObject {
    @Published public private(set) var isActivityActive: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    private var currentActivity: Activity<LyricsAttributes>?

    public init() {
        // Adopt existing activity if one is already running from earlier in the session
        let existing = Activity<LyricsAttributes>.activities
        if let first = existing.first {
            self.currentActivity = first
            self.isActivityActive = true
            // Clean up any stray duplicates from older builds
            if existing.count > 1 {
                for extra in existing.dropFirst() {
                    Task {
                        await extra.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        }
    }

    /// Starts a single Live Activity if none exists, or updates the existing one in-place without notifications.
    public func startActivity(track: TrackInfo, initialSyncState: SyncState) {
        // If an activity already exists, reuse it and update in-place instead of requesting a new banner!
        if let existing = currentActivity ?? Activity<LyricsAttributes>.activities.first,
           existing.activityState == .active {
            self.currentActivity = existing
            self.isActivityActive = true
            self.lastErrorMessage = nil
            updateActivity(track: track, syncState: initialSyncState, isPlaying: true)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            self.lastErrorMessage = "Activa 'Actividades en vivo' en Ajustes > LyricsCarPlay."
            return
        }

        let attributes = LyricsAttributes(trackId: "carplay-lyrics-session")
        let initialContentState = LyricsAttributes.ContentState(
            currentLine: initialSyncState.currentLine,
            nextLine: initialSyncState.nextLine,
            previousLine: initialSyncState.previousLine,
            trackTitle: track.title,
            artistName: track.artist,
            progress: initialSyncState.progress,
            isPlaying: true
        )

        do {
            let activity = try Activity<LyricsAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            self.isActivityActive = true
            self.lastErrorMessage = nil
        } catch {
            // Only report error if there is truly no active activity running
            if Activity<LyricsAttributes>.activities.isEmpty {
                self.isActivityActive = false
            }
            print("Aviso al iniciar Live Activity: \(error.localizedDescription)")
        }
    }

    /// Updates the running Live Activity card silently in-place (alertConfiguration: nil prevents notification banners).
    public func updateActivity(track: TrackInfo, syncState: SyncState, isPlaying: Bool) {
        guard let activity = currentActivity ?? Activity<LyricsAttributes>.activities.first else {
            return
        }
        self.currentActivity = activity
        self.isActivityActive = true
        self.lastErrorMessage = nil

        let updatedContentState = LyricsAttributes.ContentState(
            currentLine: syncState.currentLine,
            nextLine: syncState.nextLine,
            previousLine: syncState.previousLine,
            trackTitle: track.title,
            artistName: track.artist,
            progress: syncState.progress,
            isPlaying: isPlaying
        )

        Task {
            await activity.update(
                ActivityContent<LyricsAttributes.ContentState>(
                    state: updatedContentState,
                    staleDate: nil
                ),
                alertConfiguration: nil
            )
        }
    }

    /// Ends all active Live Activity cards immediately and synchronously resets state.
    public func endActivity() {
        let activitiesToEnd = Activity<LyricsAttributes>.activities
        let tracked = self.currentActivity
        self.currentActivity = nil
        self.isActivityActive = false

        Task {
            if let tracked = tracked {
                await tracked.end(nil, dismissalPolicy: .immediate)
            }
            for activity in activitiesToEnd {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
