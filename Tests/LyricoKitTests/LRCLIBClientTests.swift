import Testing
import Foundation
@testable import LyricoKit

@Suite("LRCLIBClient")
struct LRCLIBClientTests {
    @Test("request URL encodes artist, title, duration as query items")
    func requestURL() throws {
        let client = LRCLIBClient(transport: { _ in
            (Data(), HTTPURLResponse())
        })
        let request = try client.makeRequest(
            artist: "Linkin Park",
            title: "In the End",
            duration: 216.4
        )
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components.host == "lrclib.net")
        #expect(components.path == "/api/get")
        #expect(items["artist_name"] == "Linkin Park")
        #expect(items["track_name"] == "In the End")
        #expect(items["duration"] == "216")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Lyrico/") == true)
    }

    @Test("request omits duration when nil")
    func requestOmitsDuration() throws {
        let client = LRCLIBClient(transport: { _ in (Data(), HTTPURLResponse()) })
        let request = try client.makeRequest(artist: "A", title: "B", duration: nil)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect((components.queryItems ?? []).contains { $0.name == "duration" } == false)
    }

    @Test("successful fetch decodes track")
    func fetchSuccess() async throws {
        let json = """
            {
              "id": 1,
              "trackName": "Song",
              "artistName": "Artist",
              "albumName": "Album",
              "duration": 180.0,
              "instrumental": false,
              "plainLyrics": "plain",
              "syncedLyrics": "[00:01.00]Hi"
            }
            """.data(using: .utf8)!

        let client = LRCLIBClient(cache: nil) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json, response)
        }

        let track = try await client.fetch(artist: "Artist", title: "Song", duration: 180)
        #expect(track.id == 1)
        #expect(track.trackName == "Song")
        #expect(track.syncedLyrics == "[00:01.00]Hi")
    }

    @Test("404 throws notFound")
    func notFound() async throws {
        let client = LRCLIBClient(cache: nil) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        await #expect(throws: LRCLIBError.notFound) {
            _ = try await client.fetch(artist: "Nobody", title: "Nothing")
        }
    }

    @Test("non-2xx throws http error with status")
    func httpError() async throws {
        let client = LRCLIBClient(cache: nil) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        await #expect(throws: LRCLIBError.http(status: 500)) {
            _ = try await client.fetch(artist: "A", title: "B")
        }
    }

    @Test("malformed JSON throws decoding error")
    func decodingError() async throws {
        let client = LRCLIBClient(cache: nil) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("not json".utf8), response)
        }

        await #expect(throws: (any Error).self) {
            _ = try await client.fetch(artist: "A", title: "B")
        }
    }

    @Test("cache returns stored data without hitting transport")
    func cacheHitSkipsTransport() async throws {
        let json = """
            {
              "id": 7,
              "trackName": "Cached",
              "artistName": "Cache",
              "albumName": null,
              "duration": null,
              "instrumental": false,
              "plainLyrics": null,
              "syncedLyrics": null
            }
            """.data(using: .utf8)!

        let cache = InMemoryCache()
        await cache.store(
            key: LRCLIBClient.cacheKey(artist: "Cache", title: "Cached", duration: nil),
            data: json
        )

        let client = LRCLIBClient(cache: cache) { _ in
            Issue.record("transport should not be called on cache hit")
            return (Data(), HTTPURLResponse())
        }

        let track = try await client.fetch(artist: "Cache", title: "Cached")
        #expect(track.id == 7)
        #expect(track.trackName == "Cached")
    }

    @Test("successful fetch stores response in cache")
    func cacheStoresResponse() async throws {
        let json = """
            {
              "id": 42,
              "trackName": "Store",
              "artistName": "Me",
              "albumName": null,
              "duration": null,
              "instrumental": false,
              "plainLyrics": null,
              "syncedLyrics": null
            }
            """.data(using: .utf8)!

        let cache = InMemoryCache()
        let client = LRCLIBClient(cache: cache) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json, response)
        }

        _ = try await client.fetch(artist: "Me", title: "Store")
        let stored = await cache.load(
            key: LRCLIBClient.cacheKey(artist: "Me", title: "Store", duration: nil)
        )
        #expect(stored == json)
    }

    @Test("cache key normalizes case and rounds duration")
    func cacheKeyNormalization() {
        let a = LRCLIBClient.cacheKey(artist: "Foo", title: "Bar", duration: 12.4)
        let b = LRCLIBClient.cacheKey(artist: "FOO", title: "bar", duration: 12.0)
        #expect(a == b)
        #expect(a == "foo|bar|12")
    }
}

private actor InMemoryCache: LRCLIBCache {
    private var storage: [String: Data] = [:]

    func load(key: String) -> Data? { storage[key] }
    func store(key: String, data: Data) { storage[key] = data }
}
