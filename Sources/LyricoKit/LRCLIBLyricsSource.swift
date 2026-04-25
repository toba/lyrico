public import Foundation

public struct LRCLIBLyricsSource: LyricsSource {
  private let client: LRCLIBClient

  public init(client: LRCLIBClient = LRCLIBClient()) {
    self.client = client
  }

  public func fetch(
    artist: String,
    title: String,
    duration: TimeInterval?
  ) async throws -> LRCDocument? {
    let track: LRCLIBTrack
    do {
      track = try await client.fetch(artist: artist, title: title, duration: duration)
    } catch LRCLIBError.notFound {
      return nil
    }

    if let synced = track.syncedLyrics, !synced.isEmpty {
      return LRCParser.parse(synced)
    }
    if let plain = track.plainLyrics, !plain.isEmpty {
      return LRCParser.parse(plain)
    }
    return nil
  }
}
