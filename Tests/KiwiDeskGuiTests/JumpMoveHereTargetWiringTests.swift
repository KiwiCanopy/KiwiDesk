import Foundation
import Testing

@testable import KiwiDesk

/// KiwiHub hands Move here the Space shown on the screen it opened
/// on (#2791): `JumpMoveHereScreenTests` drives the core door and
/// stays green on a panel that never passes the Space.
@Suite("KiwiHub Move here target wiring (#2791)")
struct JumpMoveHereTargetWiringTests {
    private static func squashed(_ file: URL) throws -> String {
        try SourceScan.blankedSource(at: file)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the pick moves into the panel's screen's Space")
    func pickPassesThePanelSpace() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let controller = try Self.squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpPanelController.swift"
            )
        )
        #expect(
            controller.contains("pickerSpace=core.layoutPickerSpace()")
        )
        #expect(
            controller.occurrences(
                of: "core.moveHere(entry.target,into:pickerSpace)"
            ) == 1
        )
        // No GUI caller reaches the door without a Space.
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(files.count > 50)
        for file in files {
            let source = try Self.squashed(file)
            #expect(
                source.occurrences(of: ".moveHere(")
                    == source.occurrences(of: ",into:pickerSpace)"),
                "\(file.lastPathComponent)"
            )
        }
    }
}
