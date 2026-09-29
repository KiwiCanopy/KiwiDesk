import Foundation
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ Scroll gestures (#1656): the group leads the
/// drawer, the recorder's refusal is Core's, the travel field
/// greys while the box is off, and every value row carries its
/// "Applies to" column.
@Suite("Scroll gestures group wiring (#1656)")
struct GesturesScrollWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir = "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func source(_ file: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(dir + file),
                encoding: .utf8
            )
        )
    }

    @Test("the scroll group is the drawer's first")
    func scrollGroupLeads() throws {
        let drawer = try Self.source("GesturesDrawer.swift")
        let scroll = try #require(
            drawer.range(of: "GesturesScrollEntries(model:")
        )
        let windows = try #require(
            drawer.range(of: "\"shortcuts.gestures.group.windows\"")
        )
        let heading = try #require(
            drawer.range(of: "\"shortcuts.gestures.group.scroll\"")
        )
        #expect(heading.lowerBound < scroll.lowerBound)
        #expect(scroll.lowerBound < windows.lowerBound)
    }

    @Test("a recorded chord is judged by Core's refusal before it lands")
    func recorderAsksCore() throws {
        let field = try Self.source("ScrollChordRecorderField.swift")
        let refusal = try #require(
            field.range(of: "ScrollChordRefusal.of(recorded, other: other)")
        )
        let write = try #require(field.range(of: "chord = recorded"))
        #expect(refusal.lowerBound < write.lowerBound)
        #expect(field.contains("mode: .modifiers"))
    }

    @Test("the travel field greys, never hides, while the box is off")
    func travelGreys() throws {
        let group = try Self.source("GesturesScrollEntries.swift")
        #expect(group.contains(".disabled(!gestures.longSwipes)"))
        #expect(!group.contains("if gestures.longSwipes"))
    }

    @Test("every value row carries its Applies to column")
    func everyRowReaches() throws {
        let group = try Self.source("GesturesScrollEntries.swift")
        for field in [
            "reachRow(.pan)", "reachRow(.longSwipes)",
            "reachRow(.stepDistance)", ".naturalTrackpad,",
            ".naturalMouse,",
        ] {
            #expect(group.contains(field), "\(field) has no column")
        }
        #expect(group.contains("family: .scroll"))
    }
}
