public import Foundation

public struct LRCLIBTrack: Sendable, Hashable, Codable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool
    public let plainLyrics: String?
    public let syncedLyrics: String?
}

public enum LRCLIBError: Error, Sendable, Equatable {
    case notFound
    case invalidResponse
    case http(status: Int)
    case decoding(String)
    case transport(String)
}

public protocol LRCLIBCache: Sendable {
    func load(key: String) async -> Data?
    func store(key: String, data: Data) async
}

public struct LRCLIBClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public static let defaultBaseURL = URL(string: "https://lrclib.net")!

    private let baseURL: URL
    private let userAgent: String
    private let transport: Transport
    private let cache: (any LRCLIBCache)?

    public init(
        baseURL: URL = LRCLIBClient.defaultBaseURL,
        userAgent: String = "Lyrico/\(Lyrico.version)",
        cache: (any LRCLIBCache)? = nil,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.cache = cache
        self.transport = transport
    }

    public func fetch(
        artist: String,
        title: String,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBTrack {
        let key = Self.cacheKey(artist: artist, title: title, duration: duration)

        if let cached = await cache?.load(key: key),
           let track = try? Self.decoder.decode(LRCLIBTrack.self, from: cached)
        {
            return track
        }

        let request = try makeRequest(artist: artist, title: title, duration: duration)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await transport(request)
        } catch {
            throw LRCLIBError.transport(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else { throw LRCLIBError.invalidResponse }

        if http.statusCode == 404 { throw LRCLIBError.notFound }

        guard (200..<300).contains(http.statusCode) else {
            throw LRCLIBError.http(status: http.statusCode)
        }

        let track: LRCLIBTrack

        do {
            track = try Self.decoder.decode(LRCLIBTrack.self, from: data)
        } catch {
            throw LRCLIBError.decoding(String(describing: error))
        }

        await cache?.store(key: key, data: data)
        return track
    }

    func makeRequest(artist: String, title: String, duration: TimeInterval?) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appending(path: "api/get"),
            resolvingAgainstBaseURL: false
        ) else { throw LRCLIBError.invalidResponse }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
        ]

        if let duration {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components.queryItems = items

        guard let url = components.url else { throw LRCLIBError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func cacheKey(artist: String, title: String, duration: TimeInterval?) -> String {
        let dur = duration.map { String(Int($0.rounded())) } ?? "_"
        return "\(artist.lowercased())|\(title.lowercased())|\(dur)"
    }

    private static let decoder = JSONDecoder()
}

public actor FileLRCLIBCache: LRCLIBCache {
    private let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func defaultDirectory() throws -> URL {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = caches.appending(path: "Lyrico")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func load(key: String) -> Data? { try? Data(contentsOf: fileURL(for: key)) }

    public func store(key: String, data: Data) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: key), options: [.atomic])
    }

    private func fileURL(for key: String) -> URL {
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return directory.appending(path: "\(encoded).json")
    }
}
