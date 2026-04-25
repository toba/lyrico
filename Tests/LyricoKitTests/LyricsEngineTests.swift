import Foundation
import Testing

@testable import LyricoKit

@Suite("LyricsEngine.activeIndex")
struct ActiveIndexTests {
  private let lines: [LyricLine] = [
    LyricLine(timestamp: 1.0, text: "A"),
    LyricLine(timestamp: 5.0, text: "B"),
    LyricLine(timestamp: 10.0, text: "C"),
    LyricLine(timestamp: 15.0, text: "D"),
  ]

  @Test("position before first line returns nil")
  func beforeFirst() {
    #expect(LyricsEngine.activeIndex(in: lines, at: 0.5) == nil)
  }

  @Test("position exactly at a timestamp selects that line")
  func exactMatch() {
    #expect(LyricsEngine.activeIndex(in: lines, at: 5.0) == 1)
  }

  @Test("position between timestamps selects the previous line")
  func betweenTimestamps() {
    #expect(LyricsEngine.activeIndex(in: lines, at: 7.5) == 1)
    #expect(LyricsEngine.activeIndex(in: lines, at: 12.0) == 2)
  }

  @Test("position past the last line selects the last line")
  func afterLast() {
    #expect(LyricsEngine.activeIndex(in: lines, at: 999.0) == 3)
  }

  @Test("empty lines returns nil")
  func emptyLines() {
    #expect(LyricsEngine.activeIndex(in: [], at: 5.0) == nil)
  }
}

@MainActor
@Suite("LyricsEngine")
struct LyricsEngineTests {
  @Test("nil snapshot resets state to idle")
  func nilSnapshotIsIdle() async {
    let engine = LyricsEngine(lyrics: StubLyricsSource(document: .stub))
    await engine.update(with: nil)
    #expect(engine.status == .idle)
    #expect(engine.document == nil)
    #expect(engine.currentIndex == nil)
    #expect(engine.nowPlaying == nil)
  }

  @Test("snapshot without artist/title is idle")
  func missingMetadataIsIdle() async {
    let engine = LyricsEngine(lyrics: StubLyricsSource(document: .stub))
    let snap = PlaybackSnapshot(artist: nil, title: nil, position: 0, isPlaying: true)
    await engine.update(with: snap)
    #expect(engine.status == .idle)
    #expect(engine.document == nil)
  }

  @Test("successful fetch sets ready status and document")
  func fetchSuccess() async {
    let source = StubLyricsSource(document: .stub)
    let engine = LyricsEngine(lyrics: source)
    let snap = PlaybackSnapshot(artist: "Artist", title: "Song", duration: 120, position: 5, isPlaying: true)
    await engine.update(with: snap)
    #expect(engine.status == .ready)
    #expect(engine.document?.lines.count == 3)
    #expect(engine.currentIndex == 1)  // position 5 → second line at t=5
    let calls = await source.callCount
    #expect(calls == 1)
  }

  @Test("not found sets notFound status")
  func fetchNotFound() async {
    let source = StubLyricsSource(document: nil)
    let engine = LyricsEngine(lyrics: source)
    let snap = PlaybackSnapshot(artist: "A", title: "B", position: 0, isPlaying: true)
    await engine.update(with: snap)
    #expect(engine.status == .notFound)
    #expect(engine.document == nil)
  }

  @Test("fetch error sets error status")
  func fetchError() async {
    let source = StubLyricsSource(error: StubError.boom)
    let engine = LyricsEngine(lyrics: source)
    let snap = PlaybackSnapshot(artist: "A", title: "B", position: 0, isPlaying: true)
    await engine.update(with: snap)
    if case .error = engine.status {
      // ok
    } else {
      Issue.record("expected error status, got \(engine.status)")
    }
  }

  @Test("subsequent ticks for same track do not refetch")
  func sameTrackNoRefetch() async {
    let source = StubLyricsSource(document: .stub)
    let engine = LyricsEngine(lyrics: source)
    let snap1 = PlaybackSnapshot(artist: "A", title: "B", duration: 60, position: 1, isPlaying: true)
    let snap2 = PlaybackSnapshot(artist: "A", title: "B", duration: 60, position: 6, isPlaying: true)
    await engine.update(with: snap1)
    await engine.update(with: snap2)
    let calls = await source.callCount
    #expect(calls == 1)
    #expect(engine.currentIndex == 1)
  }

  @Test("track change triggers refetch")
  func trackChangeRefetches() async {
    let source = StubLyricsSource(document: .stub)
    let engine = LyricsEngine(lyrics: source)
    let snap1 = PlaybackSnapshot(artist: "A", title: "One", position: 0, isPlaying: true)
    let snap2 = PlaybackSnapshot(artist: "A", title: "Two", position: 0, isPlaying: true)
    await engine.update(with: snap1)
    await engine.update(with: snap2)
    let calls = await source.callCount
    #expect(calls == 2)
  }

  @Test("position update advances currentIndex without refetch")
  func currentIndexFollowsPosition() async {
    let source = StubLyricsSource(document: .stub)
    let engine = LyricsEngine(lyrics: source)
    await engine.update(with: PlaybackSnapshot(artist: "A", title: "B", position: 0, isPlaying: true))
    #expect(engine.currentIndex == 0)
    await engine.update(with: PlaybackSnapshot(artist: "A", title: "B", position: 6, isPlaying: true))
    #expect(engine.currentIndex == 1)
    await engine.update(with: PlaybackSnapshot(artist: "A", title: "B", position: 12, isPlaying: true))
    #expect(engine.currentIndex == 2)
  }
}

private actor StubLyricsSource: LyricsSource {
  private(set) var callCount: Int = 0
  private let document: LRCDocument?
  private let error: (any Error)?

  init(document: LRCDocument? = nil, error: (any Error)? = nil) {
    self.document = document
    self.error = error
  }

  func fetch(artist: String, title: String, duration: TimeInterval?) async throws -> LRCDocument? {
    callCount += 1
    if let error { throw error }
    return document
  }
}

private enum StubError: Error { case boom }

extension LRCDocument {
  fileprivate static let stub = LRCDocument(
    lines: [
      LyricLine(timestamp: 0.0, text: "Line A"),
      LyricLine(timestamp: 5.0, text: "Line B"),
      LyricLine(timestamp: 10.0, text: "Line C"),
    ],
    metadata: LRCMetadata()
  )
}
