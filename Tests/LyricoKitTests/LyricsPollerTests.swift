import Testing
import Foundation
@testable import LyricoKit

@Suite("LyricsPoller")
struct LyricsPollerTests {
    @Test("tick reads snapshot and forwards to engine")
    func tickForwardsSnapshot() async {
        let snap = PlaybackSnapshot(
            artist: "A",
            title: "B",
            duration: 60,
            position: 5,
            isPlaying: true
        )
        let source = FakePlaybackSource(snapshots: [snap])
        let lyrics = StubLyricsSource(document: .stub)
        let engine = await LyricsEngine(lyrics: lyrics)
        let poller = LyricsPoller(engine: engine, source: source)

        await poller.tick()

        let nowPlaying = await engine.nowPlaying
        let status = await engine.status
        #expect(nowPlaying == snap)
        #expect(status == .ready)
    }

    @Test("tick surfaces source errors to engine status")
    func tickSurfacesSourceErrors() async {
        let source = FakePlaybackSource(error: FakeError.boom)
        let lyrics = StubLyricsSource(document: .stub)
        let engine = await LyricsEngine(lyrics: lyrics)
        let poller = LyricsPoller(engine: engine, source: source)

        await poller.tick()

        let nowPlaying = await engine.nowPlaying
        let status = await engine.status
        #expect(nowPlaying == nil)
        if case .error = status {} else {
            Issue.record("expected .error status, got \(status)")
        }
    }

    @Test("start triggers periodic ticks; stop ends the loop")
    func startStopRunsTicks() async throws {
        let snap = PlaybackSnapshot(artist: "A", title: "B", position: 0, isPlaying: true)
        let source = FakePlaybackSource(snapshots: Array(repeating: snap, count: 100))
        let lyrics = StubLyricsSource(document: .stub)
        let engine = await LyricsEngine(lyrics: lyrics)
        let poller = LyricsPoller(engine: engine, source: source, interval: .milliseconds(5))

        await poller.start()
        try await Task.sleep(for: .milliseconds(40))
        await poller.stop()

        let calls = await source.callCount
        #expect(calls >= 2)
    }
}

private actor FakePlaybackSource: PlaybackSource {
    private var snapshots: [PlaybackSnapshot]
    private let error: (any Error)?
    private(set) var callCount: Int = 0

    init(snapshots: [PlaybackSnapshot] = [], error: (any Error)? = nil) {
        self.snapshots = snapshots
        self.error = error
    }

    func snapshot() async throws -> PlaybackSnapshot? {
        callCount += 1
        if let error { throw error }
        if snapshots.isEmpty { return nil }
        return snapshots.removeFirst()
    }
}

private enum FakeError: Error { case boom }

private actor StubLyricsSource: LyricsSource {
    private let document: LRCDocument?

    init(document: LRCDocument?) { self.document = document }

    func fetch(
        artist _: String, title _: String, duration _: TimeInterval?
    ) async throws -> LRCDocument? { document }
}

fileprivate extension LRCDocument {
    static let stub = LRCDocument(
        lines: [LyricLine(timestamp: 0, text: "Hi")],
        metadata: LRCMetadata()
    )
}
