import LyricoKit
import SwiftUI

@main
struct LyricoApp: App {
  @State private var engine: LyricsEngine
  @State private var poller: LyricsPoller?

  init() {
    let cache = Self.makeCache()
    let client = LRCLIBClient(cache: cache)
    let lyrics = LRCLIBLyricsSource(client: client)
    _engine = State(wrappedValue: LyricsEngine(lyrics: lyrics))
  }

  var body: some Scene {
    Window("Lyrico", id: "lyrico-overlay") {
      LyricsView(engine: engine)
        .task {
          let player = SwinsianClient()
          let poller = LyricsPoller(engine: engine, source: player)
          self.poller = poller
          await poller.start()
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowLevel(.floating)
    .windowResizability(.contentSize)
  }

  private static func makeCache() -> (any LRCLIBCache)? {
    do {
      let dir = try FileLRCLIBCache.defaultDirectory()
      return FileLRCLIBCache(directory: dir)
    } catch {
      return nil
    }
  }
}
