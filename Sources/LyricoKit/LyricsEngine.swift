public import Foundation
public import Observation

public struct PlaybackSnapshot: Sendable, Hashable {
    public let trackID: String?
    public let artist: String?
    public let title: String?
    public let album: String?
    public let duration: TimeInterval?
    public let position: TimeInterval
    public let isPlaying: Bool

    public init(
        trackID: String? = nil,
        artist: String?,
        title: String?,
        album: String? = nil,
        duration: TimeInterval? = nil,
        position: TimeInterval,
        isPlaying: Bool
    ) {
        self.trackID = trackID
        self.artist = artist
        self.title = title
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
    }
}

public protocol PlaybackSource: Sendable {
    func snapshot() async throws -> PlaybackSnapshot?
}

public protocol LyricsSource: Sendable {
    func fetch(artist: String, title: String, duration: TimeInterval?) async throws -> LRCDocument?
}

public enum LyricsStatus: Sendable, Equatable {
    case idle
    case fetching
    case ready
    case notFound
    case error(String)
}

@MainActor
@Observable
public final class LyricsEngine {
    public private(set) var document: LRCDocument?
    public private(set) var nowPlaying: PlaybackSnapshot?
    public private(set) var currentIndex: Int?
    public private(set) var status: LyricsStatus

    @ObservationIgnored private let lyrics: any LyricsSource
    @ObservationIgnored private var lastFetchKey: TrackKey?

    public init(lyrics: any LyricsSource) {
        self.lyrics = lyrics
        document = nil
        nowPlaying = nil
        currentIndex = nil
        status = .idle
    }

    public func update(with snapshot: PlaybackSnapshot?) async {
        nowPlaying = snapshot

        guard let snapshot, let artist = snapshot.artist, let title = snapshot.title else {
            document = nil
            currentIndex = nil
            status = .idle
            lastFetchKey = nil
            return
        }

        let key = TrackKey(artist: artist, title: title, duration: snapshot.duration)

        if key != lastFetchKey {
            lastFetchKey = key
            document = nil
            currentIndex = nil
            status = .fetching

            let result: Result<LRCDocument?, any Error>

            do {
                let doc = try await lyrics.fetch(
                    artist: artist,
                    title: title,
                    duration: snapshot.duration
                )
                result = .success(doc)
            } catch {
                result = .failure(error)
            }

            guard lastFetchKey == key else { return }

            switch result {
                case let .success(doc):
                    document = doc
                    status = (doc == nil || (doc?.lines.isEmpty ?? true)) ? .notFound : .ready
                case let .failure(error):
                    document = nil
                    status = .error(String(describing: error))
            }
        }

        if let document, let position = nowPlaying?.position {
            currentIndex = Self.activeIndex(in: document.lines, at: position)
        }
    }

    public static nonisolated func activeIndex(
        in lines: [LyricLine], at position: TimeInterval
    ) -> Int? {
        guard !lines.isEmpty else { return nil }
        var lo = 0
        var hi = lines.count

        while lo < hi {
            let mid = (lo + hi) / 2
            let stamp = lines[mid].timestamp ?? 0

            if stamp <= position { lo = mid + 1 } else { hi = mid }
        }
        return lo == 0 ? nil : lo - 1
    }
}

private struct TrackKey: Hashable, Sendable {
    let artist: String
    let title: String
    let duration: TimeInterval?
}
