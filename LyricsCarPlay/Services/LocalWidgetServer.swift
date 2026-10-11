import Foundation
import Network

public struct WidgetScheduledLine: Codable {
    public let date: Date
    public let currentLine: String
    public let nextLine: String

    public init(date: Date, currentLine: String, nextLine: String) {
        self.date = date
        self.currentLine = currentLine
        self.nextLine = nextLine
    }
}

public struct WidgetSyncPayload: Codable {
    public let trackTitle: String
    public let artistName: String
    public let isPlaying: Bool
    public let entries: [WidgetScheduledLine]

    public init(trackTitle: String, artistName: String, isPlaying: Bool, entries: [WidgetScheduledLine]) {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.isPlaying = isPlaying
        self.entries = entries
    }
}

/// Lightweight localhost IPC server (127.0.0.1:49281) so the WidgetExtension can fetch
/// synchronized lyric timelines without requiring paid App Group entitlements when sideloaded.
public final class LocalWidgetServer {
    public static let shared = LocalWidgetServer()
    private var listener: NWListener?
    private var currentJSONData: Data = Data("{}".utf8)
    private let queue = DispatchQueue(label: "com.antigravity.LyricsCarPlay.WidgetServer")

    private init() {
        start()
    }

    public func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            guard let port = NWEndpoint.Port(rawValue: 49281) else { return }
            listener = try NWListener(using: params, on: port)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: queue)
        } catch {
            print("LocalWidgetServer error: \(error.localizedDescription)")
        }
    }

    public func updatePayload(_ payload: WidgetSyncPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let data = try? encoder.encode(payload) {
            queue.async {
                self.currentJSONData = data
            }
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] _, _, _, _ in
            guard let self = self else {
                connection.cancel()
                return
            }
            let body = self.currentJSONData
            let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            var response = Data(header.utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
