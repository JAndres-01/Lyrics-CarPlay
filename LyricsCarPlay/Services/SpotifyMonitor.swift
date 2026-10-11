import AuthenticationServices
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
public final class SpotifyMonitor: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published public private(set) var currentTrack: TrackInfo?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentPlaybackTime: TimeInterval = 0.0
    @Published public var accessToken: String? {
        didSet {
            UserDefaults.standard.set(accessToken, forKey: "SpotifyAccessToken")
        }
    }
    @Published public var isConnected: Bool = false
    @Published public var errorMessage: String?

    // Default Spotify Client ID or custom user-provided Client ID
    @Published public var clientId: String = "266da5c6efea489d81d2273bc95ee679" {
        didSet {
            UserDefaults.standard.set(clientId, forKey: "SpotifyClientId")
        }
    }

    private var pollingTimer: AnyCancellable?
    private let redirectURI = "lyricscarplay://spotify-callback"

    public override init() {
        super.init()
        if let savedToken = UserDefaults.standard.string(forKey: "SpotifyAccessToken"), !savedToken.isEmpty {
            self.accessToken = savedToken
            self.isConnected = true
        }
        if let savedClientId = UserDefaults.standard.string(forKey: "SpotifyClientId"), !savedClientId.isEmpty {
            self.clientId = savedClientId
        }
    }

    /// Authenticates with Spotify via ASWebAuthenticationSession
    public func authenticateWithSpotify(completion: @escaping (Bool) -> Void) {
        guard let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(false)
            return
        }

        let scopes = "user-read-currently-playing%20user-read-playback-state"
        let authURLString = "https://accounts.spotify.com/authorize?client_id=\(clientId)&response_type=token&redirect_uri=\(encodedRedirect)&scope=\(scopes)&show_dialog=true"

        guard let authURL = URL(string: authURLString) else {
            completion(false)
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "lyricscarplay"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Error de autenticación: \(error.localizedDescription)"
                    completion(false)
                }
                return
            }

            guard let callbackURL = callbackURL else {
                completion(false)
                return
            }

            // Parse token from fragment: lyricscarplay://spotify-callback#access_token=...&token_type=Bearer
            let fragment = callbackURL.fragment ?? callbackURL.query ?? ""
            let params = fragment.components(separatedBy: "&")
            for param in params {
                let pair = param.components(separatedBy: "=")
                if pair.count == 2 && pair[0] == "access_token" {
                    let token = pair[1]
                    Task { @MainActor in
                        self.accessToken = token
                        self.isConnected = true
                        self.errorMessage = nil
                        completion(true)
                    }
                    return
                }
            }

            Task { @MainActor in
                self.errorMessage = "No se pudo extraer el token de Spotify."
                completion(false)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }

    /// Starts polling Spotify Currently Playing API if access token is available.
    public func startPolling(
        onTrackChanged: @escaping (TrackInfo) -> Void,
        onPlaybackTimeUpdated: @escaping (TimeInterval, Bool) -> Void
    ) {
        guard let token = accessToken, !token.isEmpty else { return }
        stopPolling()

        pollingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchCurrentlyPlaying(token: token, onTrackChanged: onTrackChanged, onPlaybackTimeUpdated: onPlaybackTimeUpdated)
                }
            }
    }

    public func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    public func disconnect() {
        stopPolling()
        accessToken = nil
        isConnected = false
        currentTrack = nil
        UserDefaults.standard.removeObject(forKey: "SpotifyAccessToken")
    }

    private func fetchCurrentlyPlaying(
        token: String,
        onTrackChanged: (TrackInfo) -> Void,
        onPlaybackTimeUpdated: (TimeInterval, Bool) -> Void
    ) async {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 204 {
                // No song currently playing
                return
            }

            if httpResponse.statusCode == 401 {
                // Token expired
                self.isConnected = false
                self.errorMessage = "Sesión de Spotify expirada. Vuelve a iniciar sesión."
                stopPolling()
                return
            }

            guard httpResponse.statusCode == 200 else { return }

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
