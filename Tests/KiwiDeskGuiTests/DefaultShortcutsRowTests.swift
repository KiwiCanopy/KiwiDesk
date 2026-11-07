import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Shortcuts & Gestures ▸ Default shortcuts (#3074): the row sits
/// under the Layers card, is always drawn, and greys Restore with
/// the reason its caption names.
@Suite("Default shortcuts row")
struct DefaultShortcutsRowTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    @Test("the state names why Restore greys")
    func restoreStates() {
        let other = KeyLayer.defaultName + "-other"
        #expect(
            DefaultShortcutsRow.restoreState(
                layer: KeyLayer.defaultName,
                hasDefaultsToRestore: true
            ) == .available
        )
        #expect(
            DefaultShortcutsRow.restoreState(
                layer: KeyLayer.defaultName,
                hasDefaultsToRestore: false
            ) == .atDefaults
        )
        // The layer outranks the count: off the default layer the
        // count is about a layer the user is not looking at.
        for has in [true, false] {
            #expect(
                DefaultShortcutsRow.restoreState(
                    layer: other,
                    hasDefaultsToRestore: has
                ) == .otherLayer
            )
        }
    }

    @Test("the row mounts once, under the Layers card")
    func mountsUnderLayers() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        let layers = try #require(body.range(of: "layersCard"))
        let row = try #require(
            body.range(of: "DefaultShortcutsRow(model: model,")
        )
        let groups = try #require(
            body.range(of: "@ViewBuilder private var actionGroups")
        )
        #expect(layers.upperBound < row.lowerBound)
        #expect(row.upperBound < groups.lowerBound)
        #expect(
            body.components(separatedBy: "DefaultShortcutsRow(")
                .count == 2
        )
    }

    @Test("Restore is greyed by its state, never withheld")
    func restoreGreysNeverHides() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/DefaultShortcutsRow.swift"
        )
        #expect(!body.contains("if model.hasDefaultsToRestore"))
        let stack = try #require(body.range(of: "HStack(spacing: 8) {"))
        let call = try #require(
            body.range(
                of: "resetButton(state)",
                range: stack.upperBound..<body.endIndex
            )
        )
        // The only branch in the button stack is Import's gate,
        // which closes before Restore is drawn.
        let between = body[stack.upperBound..<call.lowerBound]
        #expect(between.components(separatedBy: "if ").count == 2)
        #expect(between.contains("importButton\n                    }"))
        #expect(
            body.contains(
                "GreyOut(active: state != .available, "
                    + "help: caption(state))"
            )
        )
    }
}
