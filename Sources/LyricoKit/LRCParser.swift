public import Foundation

public struct LyricLine: Sendable, Hashable {
  public let timestamp: TimeInterval?
  public let text: String

  public init(timestamp: TimeInterval?, text: String) {
    self.timestamp = timestamp
    self.text = text
  }
}

public struct LRCMetadata: Sendable, Hashable {
  public var artist: String?
  public var title: String?
  public var album: String?
  public var author: String?
  public var byCreator: String?
  public var length: TimeInterval?
  public var offset: TimeInterval?

  public init() {}
}

public struct LRCDocument: Sendable, Hashable {
  public let lines: [LyricLine]
  public let metadata: LRCMetadata

  public init(lines: [LyricLine], metadata: LRCMetadata) {
    self.lines = lines
    self.metadata = metadata
  }

  public var isSynced: Bool {
    lines.contains { $0.timestamp != nil }
  }
}

public enum LRCParser {
  public static func parse(_ source: String) -> LRCDocument {
    var rawLines: [LyricLine] = []
    var metadata = LRCMetadata()
    var sawSyncedLine = false

    for rawLine in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      var remaining = rawLine
      var timestamps: [TimeInterval] = []

      while remaining.first == "[" {
        guard let close = remaining.firstIndex(of: "]") else { break }
        let inside = remaining[remaining.index(after: remaining.startIndex)..<close]

        if let timestamp = parseTimestamp(inside) {
          timestamps.append(timestamp)
          sawSyncedLine = true
        } else if let (key, value) = parseMetadata(inside) {
          applyMetadata(key: key, value: value, into: &metadata)
        } else {
          break
        }
        remaining = remaining[remaining.index(after: close)...]
      }

      let text = remaining.trimmingCharacters(in: .whitespaces)

      if timestamps.isEmpty {
        if !text.isEmpty {
          rawLines.append(LyricLine(timestamp: nil, text: text))
        }
      } else {
        for stamp in timestamps {
          rawLines.append(LyricLine(timestamp: stamp, text: text))
        }
      }
    }

    let filtered = sawSyncedLine
      ? rawLines.filter { $0.timestamp != nil }
      : rawLines

    let offset = metadata.offset ?? 0
    let adjusted: [LyricLine] = offset == 0
      ? filtered
      : filtered.map { LyricLine(timestamp: $0.timestamp.map { $0 + offset }, text: $0.text) }

    let sorted = adjusted.sorted { lhs, rhs in
      (lhs.timestamp ?? 0) < (rhs.timestamp ?? 0)
    }

    return LRCDocument(lines: sorted, metadata: metadata)
  }

  private static func parseTimestamp(_ inside: Substring) -> TimeInterval? {
    let parts = inside.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2,
      let minutes = Int(parts[0]),
      let seconds = Double(parts[1])
    else { return nil }
    return Double(minutes) * 60 + seconds
  }

  private static func parseMetadata(_ inside: Substring) -> (String, String)? {
    guard let colon = inside.firstIndex(of: ":") else { return nil }
    let key = inside[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
    let value = inside[inside.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty, key.allSatisfy(\.isLetter) else { return nil }
    return (key, value)
  }

  private static func applyMetadata(key: String, value: String, into metadata: inout LRCMetadata) {
    switch key {
    case "ar": metadata.artist = value
    case "ti": metadata.title = value
    case "al": metadata.album = value
    case "au": metadata.author = value
    case "by": metadata.byCreator = value
    case "length":
      if let parsed = parseTimestamp(Substring(value)) {
        metadata.length = parsed
      }
    case "offset":
      if let milliseconds = Double(value) {
        metadata.offset = milliseconds / 1000.0
      }
    default:
      break
    }
  }
}
