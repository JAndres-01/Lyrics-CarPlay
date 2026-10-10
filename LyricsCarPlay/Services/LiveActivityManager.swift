import ActivityKit
import Foundation

/// Controller managing the lifecycle of Live Activities (ActivityKit) for CarPlay & Dynamic Island.
@MainActor
public final class LiveActivityManager: ObservableObject {
    @Published public private(set) var isActivityActive: Bool = false
    private var currentActivity: Activity<LyricsAttributes>?

    public init() {}

    /// Starts a Live Activity for a given track and initial sync state.
    public func startActivity(track: TrackInfo, initialSyncState: SyncState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities no están habilitadas en Ajustes de iOS.")
            return
        }

        // End any existing activity first
        endActivity()

        let attributes = LyricsAttributes(trackId: track.id)
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
            print("Live Activity iniciada con éxito (ID: \(activity.id))")
        } catch {
            print("Error al iniciar Live Activity: \(error.localizedDescription)")
        }
    }

    /// Updates the running Live Activity card on CarPlay and Lock Screen.
    public func updateActivity(track: TrackInfo, syncState: SyncState, isPlaying: Bool) {
        guard let activity = currentActivity else { return }

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
                )
            )
        }
    }

    /// Ends the active Live Activity card.
    public func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(
                ActivityContent<LyricsAttributes.ContentState>(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
            self.currentActivity = nil
            self.isActivityActive = false
            print("Live Activity finalizada.")
        }
    }
}
