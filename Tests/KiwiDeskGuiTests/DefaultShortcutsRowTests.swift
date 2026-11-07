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

    /// The brace-balanced body after `marker`, whitespace collapsed.
    private static func body(
        after marker: String,
        in source: String
    ) throws -> String {
        let hit = try #require(source.range(of: marker))
        var cursor = source.distance(
            from: source.startIndex,
            to: hit.upperBound
        )
        let run = try #require(
            SourceScan.balanced(
                Array(source),
                from: &cursor,
                open: "{",
                close: "}"
            )
        )
        return run.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
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
        let page = try Self.body(
            after: "private var page: some View",
            in: body
        )
        #expect(page.contains("{ header actionGroups tail }"))
        // Inside the header's own body: one Layers card mount, then
        // the row as the header's last view.
        let header = try Self.body(
            after: "@ViewBuilder private var header: some View",
            in: body
        )
        let tokens = header.split(separator: " ")
        #expect(tokens.filter { $0.contains("layersCard") }.count == 1)
        let layers = try #require(header.range(of: " layersCard "))
        let row = try #require(
            header.range(of: "DefaultShortcutsRow(model: model,")
        )
        #expect(layers.upperBound <= row.lowerBound)
        #expect(
            header.hasSuffix(
                "DefaultShortcutsRow(model: model, selected: selection)"
            )
        )
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
        // GreyOut is the button's one dim: nothing else hides it.
        for hider in [".opacity(", ".hidden(", ".disabled("] {
            #expect(!button.contains(hider), "\(hider)")
        }
        // The row's caption names the reason the button greys for.
        #expect(squashed.contains("caption:caption(reason),"))
    }
}
