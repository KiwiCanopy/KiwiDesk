import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Shortcuts ▸ Built-in ▸ Default shortcuts (#3074, #3178, #3179):
/// the row sits under the Layers card, right above the groups it
/// rewrites, is drawn while `default` is selected alone (#3260),
/// greys Restore with the reason its caption names, and keeps what
/// Restore does in its `?`.
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

    /// A selection is not a mode (#3260): off `default` the
    /// container is not drawn, its one surfacing branch needled.
    @Test("the container leaves with the default layer")
    func containerLeavesWithItsLayer() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/DefaultShortcutsRow.swift"
        ).filter { !$0.isWhitespace }
        #expect(
            body.contains(
                "varbody:someView{letreason=restoreReason"
                    + "ifreason!=.otherLayerPicked{container(reason)}}"
            )
        )
        #expect(
            !body.contains("shortcuts.restore_defaults.other_layer")
        )
    }

    /// A hit on a row the container draws — Restore, or Import from
    /// init.lua, whose census row is Lua bindings' — while another
    /// layer is selected selects `default` first, so it lands on a
    /// drawn row (#3260).
    @Test("a hit on the container's rows selects the default layer")
    @MainActor
    func restoreHitSelectsDefault() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel()
        #expect(
            ShortcutsGates.defaultLayerRows.contains(.shortcuts(.`import`))
        )
        for key in ShortcutsGates.defaultLayerRows.sorted(by: { $0.id < $1.id }
        ) {
            // The census row's label key, the anchor its hit carries.
            guard case .key(let anchor) = key.text.label else {
                Issue.record("\(key.id) names no label key")
                continue
            }
            model.nav.shortcutsLayer = "work"
            model.showShortcutsSegment(holding: anchor)
            #expect(
                model.nav.shortcutsLayer == KeyLayer.defaultName,
                "\(key.id)"
            )
        }
        // Any other hit leaves the layer picked.
        model.nav.shortcutsLayer = "work"
        model.showShortcutsSegment(
            holding: SettingsCatalog.shortcuts.focusKeys.id
        )
        #expect(model.nav.shortcutsLayer == "work")
    }

    @Test("the row mounts once, between Layers and the groups")
    func mountsUnderLayers() throws {
        let parts = ShortcutsPagePart.parts(in: .builtIn)
        let layers = try #require(parts.firstIndex(of: .layers))
        #expect(parts.firstIndex(of: .defaultShortcuts) == layers + 1)
        #expect(parts.firstIndex(of: .showHide) == layers + 2)
        #expect(
            ShortcutsPagePart(SettingsContainer.defaultShortcuts)
                == .defaultShortcuts
        )
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        let squashed = body.filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "case.defaultShortcuts:"
                    + "DefaultShortcutsRow(model:model,selected:selection)"
            )
        )
        #expect(
            body.components(separatedBy: "DefaultShortcutsRow(")
                .count == 2
        )
    }

    @Test("Restore greys by its count, never withheld for it")
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
                    + "help: caption(reason) ?? \"\")"
            )
        )
        // GreyOut is the button's one dim: nothing else hides it.
        for hider in [".opacity(", ".hidden(", ".disabled("] {
            #expect(!button.contains(hider), "\(hider)")
        }
        // The row's caption names the reason the button greys for.
        #expect(squashed.contains("caption:caption(reason),"))
    }

    /// While Restore acts the row carries no caption, so it stays one
    /// line at every band; what Restore does is the `?` (#3178).
    @Test("the explanation is the ?, the caption a live state")
    func explanationInTheHelp() throws {
        let row = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/DefaultShortcutsRow.swift"
        ).filter { !$0.isWhitespace }
        let caption = try #require(
            SourceScan.declarationBody(
                after: "privatefunccaption(",
                in: row
            )
        )
        #expect(caption.contains("casenil:returnnil"))
        #expect(!caption.contains("shortcuts.restore_defaults.help"))
        #expect(
            row.contains(
                "privatevarrestoreExplain:String{"
                    + "restoresWhat+\"\\n\\n\"+restoreAsks}"
            )
        )
        #expect(row.contains("help:restoreExplain,"))
        let action = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsActionRow.swift"
        ).filter { !$0.isWhitespace }
        #expect(action.contains("staysInline:caption==nil"))
        let shape = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        ).filter { !$0.isWhitespace }
        #expect(shape.contains("letstacked=width.stacksRows&&!staysInline"))
    }
}
