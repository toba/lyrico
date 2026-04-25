import Testing
import Foundation
@testable import LyricoKit

@Suite("SwinsianClient.parseResponse")
struct SwinsianClientParseTests {
    private let separator = SwinsianClient.separator

    @Test("empty response means Swinsian not running")
    func emptyResponse() { #expect(SwinsianClient.parseResponse("") == nil) }

    @Test("'stopped' response means no current track")
    func stoppedResponse() { #expect(SwinsianClient.parseResponse("stopped") == nil) }

    @Test("error-prefixed response yields nil")
    func errorResponse() { #expect(SwinsianClient.parseResponse("error: bad track") == nil) }

    @Test("malformed response (wrong field count) yields nil")
    func malformedResponse() {
        let raw = ["a", "b", "c"].joined(separator: separator)
        #expect(SwinsianClient.parseResponse(raw) == nil)
    }

    @Test("well-formed response parses into snapshot")
    func wellFormed() throws {
        let raw = [
            "ABC123",
            "Linkin Park",
            "In the End",
            "Hybrid Theory",
            "216.5",
            "42.3",
            "playing",
        ].joined(separator: separator)

        let snap = try #require(SwinsianClient.parseResponse(raw))
        #expect(snap.trackID == "ABC123")
        #expect(snap.artist == "Linkin Park")
        #expect(snap.title == "In the End")
        #expect(snap.album == "Hybrid Theory")
        #expect(snap.duration == 216.5)
        #expect(snap.position == 42.3)
        #expect(snap.isPlaying)
    }

    @Test("paused state sets isPlaying to false")
    func pausedState() throws {
        let raw = ["id", "A", "B", "C", "100", "0", "paused"].joined(separator: separator)
        let snap = try #require(SwinsianClient.parseResponse(raw))
        #expect(!snap.isPlaying)
    }

    @Test("empty fields become nil")
    func emptyFieldsBecomeNil() throws {
        let raw = ["", "Artist", "Title", "", "120", "5", "playing"].joined(separator: separator)
        let snap = try #require(SwinsianClient.parseResponse(raw))
        #expect(snap.trackID == nil)
        #expect(snap.album == nil)
        #expect(snap.artist == "Artist")
    }

    @Test("non-numeric duration is nil, non-numeric position defaults to 0")
    func badNumbers() throws {
        let raw = ["id", "A", "B", "C", "missing", "junk", "playing"].joined(separator: separator)
        let snap = try #require(SwinsianClient.parseResponse(raw))
        #expect(snap.duration == nil)
        #expect(snap.position == 0)
    }

    @Test("trailing whitespace is trimmed before parsing")
    func trimsWhitespace() throws {
        let raw = ["id", "A", "B", "C", "100", "0", "playing"].joined(separator: separator) + "\n  "
        #expect(SwinsianClient.parseResponse(raw) != nil)
    }
}
