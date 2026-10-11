import AuthenticationServices
import Combine
import CryptoKit
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

/// Spotify Token Exchange response DTO
public struct SpotifyTokenResponse: Codable {
    public let access_token: String
    public let token_type: String?
    public let expires_in: Int?
    public let refresh_token: String?
}

/// Spotify API Monitor to track song metadata & progress via Spotify Web API using OAuth 2.0 PKCE.
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
    @Published public var refreshToken: String? {
        didSet {
            UserDefaults.standard.set(refreshToken, forKey: "SpotifyRefreshToken")
        }
    }
    @Published public var isConnected: Bool = false
    @Published public var errorMessage: String?

    @Published public var clientId: String = "266da5c6efea489d81d2273bc95ee679" {
        didSet {
            UserDefaults.standard.set(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "SpotifyClientId")
        }
    }

    private var pollingTimer: AnyCancellable?
    public let redirectURI = "lyricscarplay://spotify-callback"
    private var currentCodeVerifier: String?

    public override init() {
        super.init()
        if let savedToken = UserDefaults.standard.string(forKey: "SpotifyAccessToken"), !savedToken.isEmpty {
            self.accessToken = savedToken
            self.isConnected = true
        }
        if let savedRefresh = UserDefaults.standard.string(forKey: "SpotifyRefreshToken"), !savedRefresh.isEmpty {
            self.refreshToken = savedRefresh
        }
        if let savedClientId = UserDefaults.standard.string(forKey: "SpotifyClientId"), !savedClientId.isEmpty {
            self.clientId = savedClientId
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<64).map { _ in characters.randomElement()! })
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - OAuth 2.0 PKCE Authentication

    /// Authenticates with Spotify via ASWebAuthenticationSession using OAuth 2.0 PKCE (`response_type=code`)
    public func authenticateWithSpotify(completion: @escaping (Bool) -> Void) {
        let cleanClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanClientId.isEmpty else {
            self.errorMessage = "Por favor ingresa tu Spotify Client ID."
            completion(false)
            return
        }

        let verifier = generateCodeVerifier()
        self.currentCodeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: cleanClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: "user-read-currently-playing user-read-playback-state"),
            URLQueryItem(name: "show_dialog", value: "true")
        ]

        guard let authURL = components.url else {
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
                    self.errorMessage = "Autenticación cancelada: \(error.localizedDescription)"
                    completion(false)
                }
                return
            }

            guard let callbackURL = callbackURL,
                  let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                Task { @MainActor in
                    self.errorMessage = "URL de respuesta inválida."
                    completion(false)
                }
                return
            }

            if let errorParam = urlComponents.queryItems?.first(where: { $0.name == "error" })?.value {
                Task { @MainActor in
                    self.errorMessage = "Error de Spotify: \(errorParam)"
                    completion(false)
                }
                return
            }

            guard let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
                Task { @MainActor in
                    self.errorMessage = "No se recibió el código de autorización de Spotify."
                    completion(false)
                }
                return
            }

            // Exchange authorization code for access_token
            Task { @MainActor in
                let success = await self.exchangeCodeForToken(code: code, verifier: verifier, clientId: cleanClientId)
                completion(success)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    /// Exchanges the authorization `code` for an `access_token` and `refresh_token` via PKCE
    private func exchangeCodeForToken(code: String, verifier: String, clientId: String) async -> Bool {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }

            if httpResponse.statusCode == 200 {
                let tokenData = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                self.accessToken = tokenData.access_token
                if let refresh = tokenData.refresh_token {
                    self.refreshToken = refresh
                }
                self.isConnected = true
                self.errorMessage = nil
                return true
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Código \(httpResponse.statusCode)"
                self.errorMessage = "Error al obtener token: \(errorText)"
                return false
            }
        } catch {
            self.errorMessage = "Error de red al canjear código: \(error.localizedDescription)"
            return false
        }
    }

    /// Automatically refreshes the expired access token using the saved refresh token
    private func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken, !refresh.isEmpty,
              let url = URL(string: "https://accounts.spotify.com/api/token") else {
            return false
        }

        let cleanClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: cleanClientId),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refresh)
        ]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }

            let tokenData = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            self.accessToken = tokenData.access_token
            if let newRefresh = tokenData.refresh_token {
                self.refreshToken = newRefresh
            }
            self.isConnected = true
            return true
        } catch {
            return false
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }

    // MARK: - Playback Polling

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
                    guard let self = self, let currentToken = self.accessToken else { return }
                    await self.fetchCurrentlyPlaying(
                        token: currentToken,
                        onTrackChanged: onTrackChanged,
                        onPlaybackTimeUpdated: onPlaybackTimeUpdated
                    )
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
        refreshToken = nil
        isConnected = false
        currentTrack = nil
        UserDefaults.standard.removeObject(forKey: "SpotifyAccessToken")
        UserDefaults.standard.removeObject(forKey: "SpotifyRefreshToken")
    }

    private func fetchCurrentlyPlaying(
        token: String,
        onTrackChanged: @escaping (TrackInfo) -> Void,
        onPlaybackTimeUpdated: @escaping (TimeInterval, Bool) -> Void
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
                return
            }

            if httpResponse.statusCode == 401 {
                // Attempt automatic token refresh
                let refreshed = await refreshAccessToken()
                if !refreshed {
                    self.isConnected = false
                    self.errorMessage = "Sesión de Spotify expirada. Vuelve a iniciar sesión."
                    stopPolling()
                }
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
