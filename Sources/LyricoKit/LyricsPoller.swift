internal import Foundation

public actor LyricsPoller {
  public nonisolated let interval: Duration

  nonisolated private let engine: LyricsEngine
  nonisolated private let source: any PlaybackSource
  private var task: Task<Void, Never>?

  public init(
    engine: LyricsEngine,
    source: any PlaybackSource,
    interval: Duration = .milliseconds(500)
  ) {
    self.engine = engine
    self.source = source
    self.interval = interval
  }

  public func start() {
    guard task == nil else { return }
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.tick()
        try? await Task.sleep(for: self.interval)
      }
    }
  }

  public func stop() {
    task?.cancel()
    task = nil
  }

  public func tick() async {
    let snapshot: PlaybackSnapshot?
    do {
      snapshot = try await source.snapshot()
    } catch {
      snapshot = nil
    }
    await engine.update(with: snapshot)
  }
}
