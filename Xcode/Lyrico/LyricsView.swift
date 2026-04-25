import LyricoKit
import SwiftUI

struct LyricsView: View {
  @Bindable var engine: LyricsEngine

  var body: some View {
    Group {
      switch engine.status {
      case .idle:
        statusText("Waiting for Swinsian…")
      case .fetching:
        ProgressView().controlSize(.small)
      case .notFound:
        statusText("No lyrics found")
      case .error(let message):
        statusText("Error: \(message)")
          .foregroundStyle(.red)
      case .ready:
        if let document = engine.document {
          lyricsBody(document: document, currentIndex: engine.currentIndex)
        } else {
          statusText("No lyrics")
        }
      }
    }
    .padding(24)
    .frame(minWidth: 480, minHeight: 200)
    .background(.thinMaterial)
    .animation(.easeInOut(duration: 0.25), value: engine.currentIndex)
  }

  private func statusText(_ text: String) -> some View {
    Text(text)
      .font(.title3)
      .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private func lyricsBody(document: LRCDocument, currentIndex: Int?) -> some View {
    let lines = document.lines
    let prev = lineAt(offset: -1, current: currentIndex, lines: lines)
    let current = lineAt(offset: 0, current: currentIndex, lines: lines)
    let next = lineAt(offset: 1, current: currentIndex, lines: lines)

    VStack(spacing: 12) {
      lyricLine(prev, role: .surrounding)
      lyricLine(current, role: .current)
      lyricLine(next, role: .surrounding)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity, alignment: .center)
  }

  @ViewBuilder
  private func lyricLine(_ line: LyricLine?, role: LineRole) -> some View {
    let display = line?.text.isEmpty == false ? line!.text : "♪"
    Text(display)
      .font(role == .current ? .system(size: 32, weight: .semibold) : .title3)
      .foregroundStyle(role == .current ? .primary : .secondary)
      .opacity(line == nil ? 0 : (role == .current ? 1.0 : 0.55))
  }

  private func lineAt(offset: Int, current: Int?, lines: [LyricLine]) -> LyricLine? {
    guard let current else { return offset == 1 ? lines.first : nil }
    let index = current + offset
    return lines.indices.contains(index) ? lines[index] : nil
  }
}

private enum LineRole {
  case current
  case surrounding
}
