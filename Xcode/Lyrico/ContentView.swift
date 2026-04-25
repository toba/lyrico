import LyricoKit
import SwiftUI

struct ContentView: View {
  @Bindable var engine: LyricsEngine

  var body: some View {
    LyricsView(engine: engine)
  }
}
