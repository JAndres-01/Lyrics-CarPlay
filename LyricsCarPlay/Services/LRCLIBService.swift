import Foundation

/// DTO for LRCLIB API response.
public struct LRCLIBResponse: Codable {
    public let id: Int?
    public let name: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?
}

public enum LRCLIBError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case noLyricsFound
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "La URL de la API no es válida."
        case .networkError(let error): return "Error de red: \(error.localizedDescription)"
        case .noLyricsFound: return "No se encontraron letras sincronizadas para esta canción en LRCLIB."
        case .decodingError: return "Error al procesar la respuesta de la API."
        }
    }
}

/// Service to query LRCLIB API for time-synced lyrics.
public actor LRCLIBService {
    private let baseURL = "https://lrclib.net/api"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches time-synced lyrics for a given track.
    /// - Parameters:
    ///   - trackName: Song title
    ///   - artistName: Artist name
    ///   - albumName: Optional album name
    ///   - duration: Track duration in seconds
    /// - Returns: Array of `LyricLine` parsed from theSynced `.lrc` string.
    public func fetchSyncedLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> [LyricLine] {
        var components = URLComponents(string: "\(baseURL)/get")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        
        if let albumName = albumName, !albumName.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        if let duration = duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Fallback to search endpoint if exact match fails
            return try await searchSyncedLyrics(query: "\(artistName) \(trackName)")
        }

        let decoded = try JSONDecoder().decode(LRCLIBResponse.self, from: data)

        if let syncedLyrics = decoded.syncedLyrics, !syncedLyrics.isEmpty {
            return LRCParser.parse(syncedLyrics)
        } else {
            throw LRCLIBError.noLyricsFound
        }
    }

    /// Fallback search query if exact match is not indexed directly.
    private func searchSyncedLyrics(query: String) async throws -> [LyricLine] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode([LRCLIBResponse].self, from: data)

        for result in decoded {
            if let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty {
                return LRCParser.parse(syncedLyrics)
            }
        }

        throw LRCLIBError.noLyricsFound
    }
}
