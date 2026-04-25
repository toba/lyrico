import Testing
@testable import LyricoKit

@Suite("LRCParser")
struct LRCParserTests {
    @Test("empty input produces empty document")
    func emptyInput() {
        let doc = LRCParser.parse("")
        #expect(doc.lines.isEmpty)
        #expect(!doc.isSynced)
    }

    @Test("plain LRC with no timestamps yields nil-timestamp lines")
    func plainLRC() {
        let source = """
            Verse one line one
            Verse one line two

            Verse two line one
            """
        let doc = LRCParser.parse(source)
        #expect(!doc.isSynced)
        #expect(doc.lines.count == 3)
        #expect(doc.lines.allSatisfy { $0.timestamp == nil })
        #expect(
            doc.lines.map(\.text) == [
                "Verse one line one", "Verse one line two", "Verse two line one",
            ])
    }

    @Test("synced LRC parses [mm:ss.xx] timestamps")
    func syncedLRC() {
        let source = """
            [00:12.34]First line
            [00:18.50]Second line
            [01:02.00]Third line
            """
        let doc = LRCParser.parse(source)
        #expect(doc.isSynced)
        #expect(doc.lines.count == 3)
        #expect(doc.lines[0].timestamp == 12.34)
        #expect(doc.lines[0].text == "First line")
        #expect(doc.lines[1].timestamp == 18.50)
        #expect(doc.lines[2].timestamp == 62.00)
    }

    @Test("multiple timestamps on one line emit one line per timestamp")
    func multipleTimestamps() {
        let source = "[00:10.00][00:30.00][01:00.00]Repeat me"
        let doc = LRCParser.parse(source)
        #expect(doc.lines.count == 3)
        #expect(doc.lines.map(\.timestamp) == [10.0, 30.0, 60.0])
        #expect(doc.lines.allSatisfy { $0.text == "Repeat me" })
    }

    @Test("metadata tags are extracted")
    func metadataTags() {
        let source = """
            [ar:Linkin Park]
            [ti:In the End]
            [al:Hybrid Theory]
            [au:Mike Shinoda]
            [by:LRC Editor]
            [length:03:36]
            [00:12.00]It starts with one
            """
        let doc = LRCParser.parse(source)
        #expect(doc.metadata.artist == "Linkin Park")
        #expect(doc.metadata.title == "In the End")
        #expect(doc.metadata.album == "Hybrid Theory")
        #expect(doc.metadata.author == "Mike Shinoda")
        #expect(doc.metadata.byCreator == "LRC Editor")
        #expect(doc.metadata.length == 216.0)
        #expect(doc.lines.count == 1)
        #expect(doc.lines[0].timestamp == 12.0)
    }

    @Test("offset metadata shifts all timestamps")
    func offsetShiftsTimestamps() {
        let source = """
            [offset:+500]
            [00:10.00]A
            [00:20.00]B
            """
        let doc = LRCParser.parse(source)
        #expect(doc.metadata.offset == 0.5)
        #expect(doc.lines[0].timestamp == 10.5)
        #expect(doc.lines[1].timestamp == 20.5)
    }

    @Test("negative offset shifts timestamps backward")
    func negativeOffset() {
        let source = """
            [offset:-250]
            [00:10.00]A
            """
        let doc = LRCParser.parse(source)
        #expect(doc.metadata.offset == -0.25)
        #expect(doc.lines[0].timestamp == 9.75)
    }

    @Test("output is sorted by timestamp")
    func sortedOutput() {
        let source = """
            [01:00.00]Last
            [00:10.00]First
            [00:30.00]Middle
            """
        let doc = LRCParser.parse(source)
        #expect(doc.lines.map(\.text) == ["First", "Middle", "Last"])
    }

    @Test("synced files drop unbracketed text lines")
    func syncedDropsPlainLines() {
        let source = """
            header junk
            [00:10.00]Real lyric
            more junk
            """
        let doc = LRCParser.parse(source)
        #expect(doc.lines.count == 1)
        #expect(doc.lines[0].text == "Real lyric")
    }

    @Test("trailing whitespace and tabs are trimmed")
    func trimsWhitespace() {
        let source = "[00:05.00]   Hello world  \t"
        let doc = LRCParser.parse(source)
        #expect(doc.lines[0].text == "Hello world")
    }

    @Test("3-digit millisecond timestamps parse correctly")
    func threeDigitMillis() {
        let source = "[00:12.345]Precise"
        let doc = LRCParser.parse(source)
        #expect(doc.lines[0].timestamp == 12.345)
    }

    @Test("integer-only timestamp [mm:ss] parses")
    func integerSecondsTimestamp() {
        let source = "[02:14]Two fourteen"
        let doc = LRCParser.parse(source)
        #expect(doc.lines[0].timestamp == 134.0)
    }

    @Test("empty timestamped line preserves empty text")
    func emptyTimestampedLine() {
        let source = """
            [00:05.00]
            [00:10.00]Then text
            """
        let doc = LRCParser.parse(source)
        #expect(doc.lines.count == 2)
        #expect(doc.lines[0].text == "")
        #expect(doc.lines[1].text == "Then text")
    }
}
