import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts page's three parts (#3184): what each draws, where
/// the part shown is kept, and how a hit, a Go to or a conflict
/// reaches a row on the part not shown. Main-actor spend: one test
/// model per test and three small source reads.
@Suite("Shortcuts page segments")
@MainActor
struct ShortcutsSegmentTests {
    /// Each part's cards in page order; Restore sits between the
    /// Layers pick that gates it and the groups it rewrites (#3179).
    @Test("each part draws its ruled cards in order")
    func partsInOrder() {
        #expect(
            ShortcutsPagePart.parts(in: .builtIn) == [
                .conflictBanner, .modifierKeys, .layers,
                .defaultShortcuts, .showHide, .focus, .moveWindows,
                .macosDesktops, .layout, .sizeFloat, .pocket, .inactive,
            ]
        )
        #expect(
            ShortcutsPagePart.parts(in: .personal) == [
                .conflictBanner, .layers, .openApplications,
                .keySequences, .luaBindings,
            ]
        )
        #expect(ShortcutsPagePart.parts(in: .mouse) == [.gestures])
        for part in ShortcutsPagePart.allCases {
            #expect(!part.segments.isEmpty, "\(part) is drawn nowhere")
        }
    }

    /// Chips are Built-in's alone (#1520 amendment, #3184).
    @Test("every chip leads into Built-in")
    func chipsAreBuiltIn() {
        for group in ShortcutsJumpGroup.allCases {
            #expect(ShortcutsPagePart(group).segments == [.builtIn])
        }
    }

    /// Built-in on a first visit, the pick for the session, none
    /// after a fresh open.
    @Test("the part shown lives on nav, Built-in first")
    func remembered() {
        var nav = SettingsNavigation()
        #expect(nav.shortcutsSegmentSelection == .builtIn)
        nav.shortcutsSegment = .personal
        #expect(nav.shortcutsSegmentSelection == .personal)
        nav.resetSurfaces()
        #expect(nav.shortcutsSegment == nil)
    }

    /// A hit picks the part holding it; Layers, drawn on both key
    /// parts, keeps the one shown.
    @Test("a hit picks the part that holds it")
    func hitPicksThePart() {
        let model = makeTestModel()
        let catalog = SettingsCatalog.shortcuts
        model.showShortcutsSegment(holding: catalog.openApplications.id)
        #expect(model.nav.shortcutsSegment == .personal)
        model.showShortcutsSegment(holding: catalog.layersCard.control.id)
        #expect(model.nav.shortcutsSegment == .personal)
        model.showShortcutsSegment(
            holding: catalog.gestures.children.mouseResize.id
        )
        #expect(model.nav.shortcutsSegment == .mouse)
        model.showShortcutsSegment(holding: catalog.focusKeys.id)
        #expect(model.nav.shortcutsSegment == .builtIn)
        model.showShortcutsSegment(holding: "no such row")
        #expect(model.nav.shortcutsSegment == .builtIn)
    }

    /// A binding row lands on its kind's part; a shipped action's row
    /// no family lists — a deleted Space's, a deleted layer's — is an
    /// inactive one, on Built-in, so the link to it finds its part.
    @Test("a binding row is placed on its part")
    func bindingParts() {
        let model = makeTestModel()
        let rows = [
            KeyBinding(combo: "", lua: "x", kind: .sequence, label: ""),
            KeyBinding(combo: "", lua: "y", kind: .custom, label: ""),
            KeyBinding(
                combo: "",
                lua: "KiwiDesk.focus_space(\"gone\")",
                kind: .navigation,
                label: ""
            ),
            KeyBinding(
                combo: "",
                lua: "KiwiDesk.switch_layer(\"gone\")",
                kind: .navigation,
                label: ""
            ),
        ]
        model.config.layers[0].bindings = rows
        let expander = ShortcutsFamilyRows.ofDraft(
            model,
            layer: KeyLayer.defaultName
        )
        let placed = [rows[0].id.uuidString, rows[1].id.uuidString]
            .map {
                ShortcutsPagePart.placing(
                    $0,
                    expander: expander,
                    bindings: rows,
                    shown: .builtIn
                )?.segment
            }
        #expect(placed == [.personal, .personal])
        // Both are rows the Inactive card draws: a deleted Space's and
        // a deleted layer's.
        let drawn = OrphanedShortcuts.commands(
            bindings: rows,
            spaces: expander.liveSpaces,
            layers: model.config.layers.map(\.name)
        ).map(\.lua)
        #expect(Set(drawn) == [rows[2].lua, rows[3].lua])
        for row in rows[2...] {
            let gone = ShortcutsPagePart.placing(
                RecorderPreflight.rowID(row),
                expander: expander,
                bindings: rows,
                shown: .personal
            )
            #expect(gone?.part == .inactive && gone?.segment == .builtIn)
        }
        #expect(
            model.shortcutsSegment(holding: rows[1].id.uuidString)
                == .personal
        )
    }

    /// The reveal picks the part before it scrolls, the recorder's
    /// Go to switches the part before it reaches the row's, and the
    /// segment's own pick is the one writer arming the gestures play.
    @Test("hits, Go to and the pick reach the part")
    func wiring() throws {
        let reveal = try Self.source("SettingsView+Reveal.swift")
        let pick = try #require(reveal.range(of: "showShortcutsSegment("))
        let scroll = try #require(
            reveal.range(of: "model.nav.pendingScroll=scroll")
        )
        #expect(pick.lowerBound < scroll.lowerBound)
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(
            jump.contains(
                "ifletplaced,switches{model.nav.shortcutsSegment="
                    + "placed.segment}"
            )
        )
        #expect(jump.contains("!switches&&"))
        let segment = try Self.source(
            "Sections/ShortcutsSection+Segment.swift"
        )
        #expect(
            segment.contains(
                "ifpicked==.mouse,!gesturesPlayed{gesturesPlayed=true"
                    + "gesturesPlay=true}"
            )
        )
        let page = try Self.source("Sections/ShortcutsSection.swift")
        // Its declaration is the page's one write.
        #expect(page.components(separatedBy: "gesturesPlay=").count == 2)
        // A pick opens the part at its top — an anchor always laid
        // out — before the part changes.
        #expect(
            page.contains(
                ".overlay(alignment:.top){Color.clear.frame(height:1)"
                    + ".id(Self.pageTop)}"
            )
        )
        let top = try #require(
            segment.range(of: "proxy.scrollTo(Self.pageTop,anchor:.top)")
        )
        let write = try #require(
            segment.range(of: "model.nav.shortcutsSegment=picked")
        )
        #expect(top.lowerBound < write.lowerBound)
        #expect(page.contains(".environment(\\.shortcutsSegment,segment)"))
        #expect(page.contains("ifsegment==.builtIn{jumpBar("))
    }

    /// The condition on #3184: a conflict with a row of the other key
    /// part links to that row.
    @Test("a conflict links to the other part")
    func conflictLink() throws {
        let field = try Self.source(
            "Components/Keybindings/Recorder/KeyRecorderField+Conflict.swift"
        )
        #expect(field.contains("otherSegmentLinkfixElsewhereLink"))
        #expect(
            field.contains(
                "ifletother=reading?.severity.otherBinding,"
                    + "letshown=shownSegment,coordinator.scrollsInPlace,"
            )
        )
        #expect(
            field.contains(
                "letpart=coordinator.segmentHolding?("
                    + "RecorderPreflight.rowID(other)){ifpart!=shown{"
            )
        )
        #expect(
            field.contains(
                "coordinator.scrollTarget=RecorderPreflight.rowID(other)"
            )
        )
        let page = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            page.contains(
                "coordinator.segmentHolding={[model]anchorin"
                    + "model.shortcutsSegment(holding:anchor)}"
            )
        )
        let other = KeyBinding(
            combo: "",
            lua: "x",
            kind: .custom,
            label: ""
        )
        #expect(ConflictSeverity.duplicate(other).otherBinding == other)
        #expect(ConflictSeverity.sideCollapse(other).otherBinding == other)
        #expect(ConflictSeverity.unrecognized.otherBinding == nil)
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .filter { !$0.isWhitespace }
    }
}
