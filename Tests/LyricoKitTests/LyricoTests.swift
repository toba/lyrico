import Testing
@testable import LyricoKit

@Suite("Lyrico")
struct LyricoTests {
    @Test("version is non-empty")
    func versionIsNonEmpty() { #expect(!Lyrico.version.isEmpty) }
}
