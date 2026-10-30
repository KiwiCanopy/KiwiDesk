import Foundation
import Testing

@testable import KiwiDesk

/// KiwiHub hands its list and Move here the screen it opened on
/// (#2791): `JumpMoveHereScreenTests` drives the core doors and
/// stays green on a panel that never passes the screen.
@Suite("KiwiHub Move here target wiring (#2791)")
struct JumpMoveHereTargetWiringTests {
    private static func squashed(_ file: URL) throws -> String {
        try SourceScan.blankedSource(at: file)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the list and the pick read the panel's screen")
    func pickPassesThePanelSpace() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let controller = try Self.squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpPanelController.swift"
            )
        )
        #expect(controller.contains("hubDisplay=core.jumpDisplay()"))
        #expect(
            controller.occurrences(of: "core.jumpSnapshot(on:hubDisplay)")
                == 1
        )
        #expect(
            controller.occurrences(
                of: "core.moveHere(entry.target,on:hubDisplay)"
            ) == 1
        )
        // No GUI caller reaches either door without the screen.
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(files.count > 50)
        for file in files {
            let source = try Self.squashed(file)
            #expect(
                source.occurrences(of: ".moveHere(")
                    == source.occurrences(of: ",on:hubDisplay)"),
                "\(file.lastPathComponent)"
            )
            #expect(
                source.occurrences(of: ".jumpSnapshot(")
                    == source.occurrences(of: "(on:hubDisplay)"),
                "\(file.lastPathComponent)"
            )
        }
    }

    /// A Move here hop's float is placed from the frame it reports,
    /// after the filing and only for a hop: an app may report its
    /// pre-move frame after macOS carried it, while a plain Jump's
    /// un-minimize keeps its frame (#2770).
    @Test("only a hop's payment places the float, after the filing")
    func paymentPlacesTheHoppedFloat() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/JumpState.swift"
            )
        let source = try SourceScan.blankedSource(at: file)
            .split(whereSeparator: \.isWhitespace).joined()
        let pay = try #require(source.range(of: "funcpayMoveHereFocus("))
        let body = String(source[pay.upperBound...])
        let file2 = try #require(body.range(of: "fileMembership(window,"))
        let place = try #require(
            body.range(
                of: "}elseifowed.hopped,reanchorFloat(window,to:owed.space)"
            )
        )
        let focus = try #require(body.range(of: "focusWindow(window,"))
        #expect(file2.lowerBound < place.lowerBound)
        #expect(place.lowerBound < focus.lowerBound)
        #expect(body.occurrences(of: "reanchorFloat(") == 1)
    }
}
