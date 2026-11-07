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

    private func reason(
        layer: String,
        defaults: Bool
    ) -> ShortcutsGates.InertReason? {
        ShortcutsGates(
            config: GuiConfig(),
            selectedLayer: layer,
            defaultsToRestore: defaults
        ).inertReason(for: .shortcuts(.restoreDefaults))
    }

    @Test("the resolver names why Restore greys")
    func restoreReasons() {
        // A construction naming neither input greys.
        #expect(
            ShortcutsGates(config: GuiConfig())
                .inertReason(for: .shortcuts(.restoreDefaults)) != nil
        )
        let other = KeyLayer.defaultName + "-other"
        #expect(reason(layer: KeyLayer.defaultName, defaults: true) == nil)
        #expect(
            reason(layer: KeyLayer.defaultName, defaults: false)
                == .matchesDefaults
        )
        // The layer outranks the count: off the default layer the
        // count is about a layer the user is not looking at.
        for defaults in [true, false] {
            #expect(
                reason(layer: other, defaults: defaults)
                    == .otherLayerPicked
            )
        }
    }

    @Test("the row mounts once, under the Layers card")
    func mountsUnderLayers() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        // The page mounts the header, then the groups.
        let page = try #require(body.range(of: "private var page:"))
        let tail = page.upperBound..<body.endIndex
        let header = try #require(body.range(of: "header", range: tail))
        let groups = try #require(
            body.range(of: "actionGroups", range: tail)
        )
        #expect(header.upperBound < groups.lowerBound)
        // Inside the header, the row comes last, after the card.
        let decl = try #require(
            body.range(of: "@ViewBuilder private var header:")
        )
        let rest = decl.upperBound..<body.endIndex
        let layers = try #require(
            body.range(of: "layersCard", range: rest)
        )
        let row = try #require(
            body.range(of: "DefaultShortcutsRow(model: model,", range: rest)
        )
        let next = try #require(body.range(of: "private var", range: rest))
        #expect(layers.upperBound < row.lowerBound)
        #expect(row.upperBound < next.lowerBound)
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
        // The row hands the resolver both of its inputs.
        let squashed = body.filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "ShortcutsGates(config:model.config,"
                    + "selectedLayer:selected,"
                    + "defaultsToRestore:model.hasDefaultsToRestore)"
                    + ".inertReason(for:.shortcuts(.restoreDefaults))"
            )
        )
        // The button stack, brace-balanced: Import's gate, then
        // Restore as its last view, with nothing wrapping it.
        let chars = Array(body)
        let stack = try #require(body.range(of: "HStack(spacing: 8)"))
        var cursor = body.distance(
            from: body.startIndex,
            to: stack.upperBound
        )
        let run = try #require(
            SourceScan.balanced(
                chars,
                from: &cursor,
                open: "{",
                close: "}"
            )
        )
        let collapsed = run.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        #expect(
            collapsed
                == "if model.hasCustomLua, !model.editingStoredProfile "
                + "{ importButton } resetButton(reason)"
        )
        // Greyed on Restore itself, never on the stack.
        let button = try SourceScan.functionBody(
            of: "resetButton",
            in: "DefaultShortcutsRow.swift",
            under: "Settings/Sections",
            root: "Sources/KiwiDesk"
        )
        #expect(
            button.contains(
                "GreyOut(active: reason != nil, "
                    + "help: caption(reason))"
            )
        )
    }
}
