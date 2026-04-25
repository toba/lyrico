import Foundation
import Testing

@testable import LyricoKit

@Suite("LRCLIBLyricsSource")
struct LRCLIBLyricsSourceTests {
  @Test("synced lyrics produce a synced LRCDocument")
  func syncedLyrics() async throws {
    let json = """
      {
        "id": 1,
        "trackName": "Song",
        "artistName": "Artist",
        "albumName": null,
        "duration": null,
        "instrumental": false,
        "plainLyrics": "ignored",
        "syncedLyrics": "[00:01.00]Hello\\n[00:05.00]World"
      }
      """.data(using: .utf8)!

    let source = LRCLIBLyricsSource(client: makeClient(returning: json))
    let doc = try await source.fetch(artist: "Artist", title: "Song", duration: nil)
    let unwrapped = try #require(doc)
    #expect(unwrapped.isSynced)
    #expect(unwrapped.lines.count == 2)
    #expect(unwrapped.lines[0].text == "Hello")
  }

  @Test("only plain lyrics produce an unsynced document")
  func plainLyricsFallback() async throws {
    let json = """
      {
        "id": 2,
        "trackName": "Song",
        "artistName": "Artist",
        "albumName": null,
        "duration": null,
        "instrumental": false,
        "plainLyrics": "Line one\\nLine two",
        "syncedLyrics": null
      }
      """.data(using: .utf8)!

    let source = LRCLIBLyricsSource(client: makeClient(returning: json))
    let doc = try await source.fetch(artist: "A", title: "B", duration: nil)
    let unwrapped = try #require(doc)
    #expect(!unwrapped.isSynced)
    #expect(unwrapped.lines.map(\.text) == ["Line one", "Line two"])
  }

  @Test("instrumental track with no lyrics returns nil")
  func instrumentalReturnsNil() async throws {
    let json = """
      {
        "id": 3,
        "trackName": "Song",
        "artistName": "Artist",
        "albumName": null,
        "duration": null,
        "instrumental": true,
        "plainLyrics": null,
        "syncedLyrics": null
      }
      """.data(using: .utf8)!

    let source = LRCLIBLyricsSource(client: makeClient(returning: json))
    let doc = try await source.fetch(artist: "A", title: "B", duration: nil)
    #expect(doc == nil)
  }

  @Test("404 not-found maps to nil rather than throwing")
  func notFoundMapsToNil() async throws {
    let client = LRCLIBClient(cache: nil) { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 404,
        httpVersion: nil,
        headerFields: nil
      )!
      return (Data(), response)
    }
    let source = LRCLIBLyricsSource(client: client)
    let doc = try await source.fetch(artist: "Nobody", title: "Nothing", duration: nil)
    #expect(doc == nil)
  }

  @Test("transport errors propagate")
  func transportErrorPropagates() async {
    let client = LRCLIBClient(cache: nil) { _ in
      throw URLError(.notConnectedToInternet)
    }
    let source = LRCLIBLyricsSource(client: client)
    await #expect(throws: (any Error).self) {
      _ = try await source.fetch(artist: "A", title: "B", duration: nil)
    }
  }

  private func makeClient(returning data: Data) -> LRCLIBClient {
    LRCLIBClient(cache: nil) { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (data, response)
    }
  }
}
