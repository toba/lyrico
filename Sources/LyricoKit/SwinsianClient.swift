internal import Foundation

public enum SwinsianError: Error, Sendable, Equatable {
    case scriptFailed(String)
    case notAuthorized
}

public actor SwinsianClient: PlaybackSource {
    public static let bundleIdentifier = "com.swinsian.Swinsian"

    private let scriptSource: String

    public init() { self.init(scriptSource: SwinsianClient.defaultScript) }

    public init(scriptSource: String) { self.scriptSource = scriptSource }

    public func snapshot() async throws -> PlaybackSnapshot? {
        guard let script = NSAppleScript(source: scriptSource) else {
            throw SwinsianError.scriptFailed("failed to compile script")
        }

        var error: NSDictionary?
        let descriptor = unsafe script.executeAndReturnError(&error)

        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -1743 { throw SwinsianError.notAuthorized }
            if code == -600 { return nil } // Swinsian not running
            throw SwinsianError.scriptFailed(String(describing: error))
        }

        guard let raw = descriptor.stringValue else { return nil }
        return Self.parseResponse(raw)
    }

    static let separator = "\u{001F}"

    static func parseResponse(_ raw: String) -> PlaybackSnapshot? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed == "stopped" { return nil }
        if trimmed.hasPrefix("error:") { return nil }

        let parts = trimmed.split(
            separator: SwinsianClient.separator,
            omittingEmptySubsequences: false
        ).map(String.init)
        guard parts.count == 7 else { return nil }

        let trackID = parts[0].isEmpty ? nil : parts[0]
        let artist = parts[1].isEmpty ? nil : parts[1]
        let title = parts[2].isEmpty ? nil : parts[2]
        let album = parts[3].isEmpty ? nil : parts[3]
        let duration = Double(parts[4])
        let position = Double(parts[5]) ?? 0
        let state = parts[6]

        return PlaybackSnapshot(
            trackID: trackID,
            artist: artist,
            title: title,
            album: album,
            duration: duration,
            position: position,
            isPlaying: state == "playing"
        )
    }

    static let defaultScript = """
        tell application "Swinsian"
          try
            if player state is stopped then return "stopped"
            set t to current track
            set d to (ASCII character 31)
            return (id of t as text) & d & ¬
              (artist of t as text) & d & ¬
              (name of t as text) & d & ¬
              (album of t as text) & d & ¬
              (duration of t as text) & d & ¬
              (player position as text) & d & ¬
              (player state as text)
          on error errMsg
            return "error: " & errMsg
          end try
        end tell
        """
}
