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
        case .networkError(let error): return "Sin conexión y la canción aún no está en caché offline (\(error.localizedDescription))."
        case .noLyricsFound: return "No se encontraron letras sincronizadas para esta canción en LRCLIB."
        case .decodingError: return "Error al procesar la respuesta de la API."
        }
    }
}

/// Service to query LRCLIB API for time-synced lyrics with automatic local offline disk caching.
public actor LRCLIBService {
    private let baseURL = "https://lrclib.net/api"
    private let session: URLSession
    private let cacheDirectory: URL

    public init(session: URLSession = .shared) {
        self.session = session
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = docs.appendingPathComponent("LyricsOfflineCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Generates a safe filename key for caching a song's synced `.lrc` file locally.
    private func cacheFileURL(trackName: String, artistName: String) -> URL {
        let rawKey = "\(artistName.lowercased())_\(trackName.lowercased())"
        let safeKey = rawKey.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        return cacheDirectory.appendingPathComponent("\(safeKey).lrc")
    }

    /// Saves raw LRC text to local offline cache on the iPhone.
    private func saveToOfflineCache(lrcText: String, trackName: String, artistName: String) {
        let fileURL = cacheFileURL(trackName: trackName, artistName: artistName)
        try? lrcText.write(to: fileURL, atomically: true, encoding: .utf8)
        // Also store latest lyrics in standard UserDefaults for static widget preview
        UserDefaults.standard.set(trackName, forKey: "LastTrackTitle")
        UserDefaults.standard.set(artistName, forKey: "LastArtistName")
    }

    /// Loads cached LRC lines from the iPhone's internal storage if available.
    private func loadFromOfflineCache(trackName: String, artistName: String) -> [LyricLine]? {
        let fileURL = cacheFileURL(trackName: trackName, artistName: artistName)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let savedLRC = try? String(contentsOf: fileURL, encoding: .utf8),
              !savedLRC.isEmpty else {
            return nil
        }
        let parsed = LRCParser.parse(savedLRC)
        return parsed.isEmpty ? nil : parsed
    }

    /// Fetches time-synced lyrics for a given track (checks offline cache first, then LRCLIB API).
    public func fetchSyncedLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> [LyricLine] {
        // 1. Instant Offline Cache Check (0ms latency, works without internet)
        if let cached = loadFromOfflineCache(trackName: trackName, artistName: artistName) {
            return cached
        }

        // 2. Query LRCLIB API
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

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await searchSyncedLyrics(
                    query: "\(artistName) \(trackName)",
                    trackName: trackName,
                    artistName: artistName
                )
            }

            let decoded = try JSONDecoder().decode(LRCLIBResponse.self, from: data)

            if let syncedLyrics = decoded.syncedLyrics, !syncedLyrics.isEmpty {
                saveToOfflineCache(lrcText: syncedLyrics, trackName: trackName, artistName: artistName)
                return LRCParser.parse(syncedLyrics)
            } else {
                return try await searchSyncedLyrics(
                    query: "\(artistName) \(trackName)",
                    trackName: trackName,
                    artistName: artistName
                )
            }
        } catch let error as LRCLIBError {
            throw error
        } catch {
            throw LRCLIBError.networkError(error)
        }
    }

    /// Fallback search query if exact match is not indexed directly.
    private func searchSyncedLyrics(
        query: String,
        trackName: String,
        artistName: String
    ) async throws -> [LyricLine] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode([LRCLIBResponse].self, from: data)

        for result in decoded {
            if let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty {
                saveToOfflineCache(lrcText: syncedLyrics, trackName: trackName, artistName: artistName)
                return LRCParser.parse(syncedLyrics)
            }
        }

        throw LRCLIBError.noLyricsFound
    }
}
