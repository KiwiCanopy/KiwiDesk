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

    /// A cross-screen arrival drops the capture it left with, in
    /// the arrival arm ahead of the fold, which consumes the away
    /// entry the drop asks about (#2770).
    @Test("the arrival arm drops a stale capture ahead of the fold")
    func arrivalDropsTheStaleCapture() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Events.swift"
            )
        let source = try SourceScan.blankedSource(at: file)
        let drop = try #require(
            source.range(of: "dropCaptureLeftOnAnotherScreen(window)")
        )
        let fold = try #require(source.range(of: "state.apply(event)"))
        #expect(drop.lowerBound < fold.lowerBound)
    }
}
