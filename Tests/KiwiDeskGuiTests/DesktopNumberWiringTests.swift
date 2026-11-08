import Foundation
import Testing

@testable import KiwiDesk

/// A Desktop has one number, Mission Control's count across
/// screens (#3103): the labels read it, and a screen's own place
/// is the switch plate's dot alone. The landing arguments default
/// empty, so a dropped one compiles and every behavioural suite
/// stays green.
@Suite("Desktop number wiring")
struct DesktopNumberWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func squashed(_ path: String) throws -> String {
        try SourceScan.blankedSource(
            at: root.appendingPathComponent(path)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("each reading reaches its surface")
    func readingsAreWired() throws {
        let cue = try Self.squashed(
            "Sources/KiwiDeskCore/Profiles/KiwiCore+DesktopCue.swift"
        )
        #expect(cue.contains("screen:display.flatMap(screenLabel),"))
        // Literals kept: the plate's digit is an interpolation.
        let plate = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/CuePlate/DesktopCueView.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(plate.contains("Text(verbatim:\"\\(cue.number)\")"))
        #expect(plate.contains("ifindex==cue.position{"))
        let draft = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "ShortcutsFamilyRows+Draft.swift"
        )
        #expect(draft.contains("landings:model.desktopLandings"))
        let hub = try Self.squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+Shortcuts.swift"
        )
        #expect(hub.contains("landings:core.desktopLandings(in:desktops),"))
        let refresh = try Self.squashed(
            "Sources/KiwiDesk/Settings/SettingsModel+Refresh.swift"
        )
        #expect(
            refresh.contains(
                "desktopLandings=core.desktopLandings(in:desktops)"
            )
        )
    }

    /// The files that may spell `screenPlace(`: its two homes and
    /// the cue's dot. A label reading it re-opens #3103.
    private static let placeReaders: [String: Int] = [
        "Sources/KiwiDeskCore/OS/NativeSpaces.swift": 1,
        "Sources/KiwiDeskCore/OS/NativeSpaces+Desktop.swift": 2,
        "Sources/KiwiDeskCore/Profiles/DesktopSwitchCue.swift": 1,
    ]

    @Test("a screen's place is read for the dot alone")
    func placeIsNoLabel() throws {
        var found: [String: Int] = [:]
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let dir = Self.root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                let hits = try SourceScan.strippedSource(at: file)
                    .occurrences(of: "screenPlace(")
                guard hits > 0 else { continue }
                let path = String(
                    file.path.dropFirst(Self.root.path.count + 1)
                )
                found[path] = hits
            }
        }
        #expect(found == Self.placeReaders)
    }
}
