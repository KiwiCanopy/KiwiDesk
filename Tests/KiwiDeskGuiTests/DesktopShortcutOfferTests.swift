import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// WHICH macOS Desktops get a keybinding row, and what a row
/// whose Desktop is away looks like (#884's verbs, GUI half).
///
/// The offer is `live ∪ bound`: every Desktop that exists, plus
/// every Desktop an existing binding names — so a shortcut
/// survives its screen being unplugged instead of going
/// invisible, which is #92's argument one noun over. What keeps
/// that honest is the MARK: an offered-but-absent row dims and
/// says why, rather than looking exactly like a working one and
/// silently doing nothing.
///
/// `DesktopShortcutRowsTests` holds what a row says; this holds
/// when it appears. Split from that suite at the §2.1 ceiling.
///
/// `.serialized`, and the locale reset is to `"en"` rather than
/// `nil`: `panelNamesADesktopRow` compares English, so it moves
/// the process-wide `LocalizationManager`, and `nil` means
/// "System default" — the HOST's language — which would hand
/// whatever suite is mid-body a locale nobody chose (tests.md,
/// #740).
@Suite("Desktop shortcut offers", .serialized)
@MainActor
struct DesktopShortcutOfferTests {

    /// A macOS with no Desktop bridge draws NO Desktop rows —
    /// `KiwiCore.bindableDesktops` answers an empty list there,
    /// and an empty list is what makes the three families draw
    /// nothing. Offering them would offer three verbs that
    /// refuse on this machine and can never do otherwise.
    @Test("no Desktops means no Desktop rows")
    func withoutDesktopsNothingIsOffered() {
        let expander = ShortcutsFamilyRows(
            spaces: ["1"],
            icons: [:],
            desktops: [],
            absentDesktops: [],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
        for key in Self.desktopFamilies {
            #expect(expander.rows(for: key)?.isEmpty == true)
        }
    }

    /// A binding keeps its row when its Desktop stops existing.
    ///
    /// This is the Desktop answer to #92. A Desktop number is
    /// macOS topology, not user data: unplug a screen and
    /// Desktops 3–5 are gone, while the binding that named one
    /// is still Carbon-registered, still blocks the recorder,
    /// and would have no row for the duplicate-combo block's
    /// "Go to" to reach. `offeredDesktops` is the union that
    /// keeps it, and both surfaces consume it.
    @Test("a bound Desktop is offered even when it is gone")
    func aBoundDesktopSurvivesItsScreen() {
        let bindings = [
            KeyBinding(
                combo: "ctrl+alt+5",
                lua: "KiwiDesk.focus_desktop(5)",
                kind: .navigation
            )
        ]
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [1, 2],
                bindings: bindings
            ) == [1, 2, 5]
        )
        // And with the bridge absent entirely, the bound one is
        // still the only thing offered — an empty live list is
        // the capability answer, not a reason to drop a row the
        // user authored.
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [],
                bindings: bindings
            ) == [5]
        )
        // A live Desktop the bindings also name is offered once.
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [1, 5],
                bindings: bindings
            ) == [1, 5]
        )
    }

    /// A row whose Desktop is away is MARKED, and one whose
    /// Desktop is live is not.
    ///
    /// The mark is what makes the union honest: `offeredDesktops`
    /// keeps the row reachable, and without this the row for an
    /// unplugged screen renders identically to a working one and
    /// silently does nothing when pressed. Both directions are
    /// asserted — a mark on every row says as little as a mark
    /// on none.
    @Test("a row whose Desktop is away carries the mark")
    func anAwayRowIsMarked() {
        LocalizationManager.shared.select("en")
        let expander = ShortcutsFamilyRows(
            spaces: ["1"],
            icons: [:],
            desktops: [1, 2, 5],
            absentDesktops: [5],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
        for key in Self.desktopFamilies {
            let rows = expander.rows(for: key) ?? []
            #expect(rows.count == 3)
            let marked = rows.filter { $0.unavailable != nil }
            #expect(
                marked.count == 1,
                Comment(rawValue: "\(key.id) marked \(marked.count)")
            )
            #expect(marked.first?.lua.contains("(5)") == true)
            #expect(marked.first?.unavailable?().isEmpty == false)
        }
    }

    /// The mark never rides a row the user can still use. Every
    /// caller with no machine in its question — the diff
    /// readout, the conflict roster, the import classifier —
    /// passes no absent set at all, and must get clean rows.
    @Test("with nothing away, no row is marked")
    func nothingAwayMarksNothing() {
        let rows =
            KeybindingCatalog.goToDesktop([1, 2])
            + KeybindingCatalog.moveToDesktop([1, 2])
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { $0.unavailable == nil })
    }

    /// A Desktop binding recovered from `init.lua` classifies as
    /// `.navigation` and takes the catalog's own English label —
    /// by SHAPE, so it works for a Desktop that is not attached
    /// right now. Left `.custom` it would render as raw Lua in
    /// the Advanced drawer and in the panel's Custom band.
    @Test("an imported Desktop binding leaves Custom")
    func importClassifiesADesktopRow() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+7",
                        lua: "KiwiDesk.move_to_desktop(7)",
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Move to Desktop 7")
    }

    /// Anything that is not one of the three verbs parses to
    /// nil, so a future `…_desktop` verb taking something else
    /// cannot be swept into these rows, and a Space verb never
    /// is.
    @Test("only the three Desktop verbs parse")
    func onlyTheThreeVerbsParse() {
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.focus_space(\"3\")"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.rename_desktop(3)"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.focus_desktop(\"3\")"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.move_to_desktop_and_follow(3)"
            ) == 3
        )
    }

    /// A bound Desktop row reaches the ⌃⌥K panel under its real
    /// name, in the band its family is censused in — never the
    /// Custom band, which means "user-authored" and renders raw
    /// Lua untranslated in every locale (#678 item 18 is the
    /// same defect, one family over).
    @Test("a bound Desktop row is a named panel row")
    func panelNamesADesktopRow() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select("en") }
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+shift+2",
                        lua: "KiwiDesk.focus_desktop(2)",
                        kind: .navigation
                    ),
                    // Desktop 5 is NOT in the live list below.
                    // That is the whole point of the fixture:
                    // with every bound Desktop already live, the
                    // builder's `offeredDesktops` widening adds
                    // nothing, and deleting that call outright
                    // left all 86 shortcut tests green
                    // (guard-prover, 2026-08-26).
                    KeyBinding(
                        combo: "ctrl+alt+cmd+5",
                        lua:
                            "KiwiDesk.move_to_desktop_and_follow(5)",
                        kind: .navigation
                    ),
                ]
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [1, 2],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.custom.isEmpty)
        let labels = reference.controls.flatMap(\.rows).map(
            \.label
        )
        #expect(labels.contains("Go to Desktop 2"))
        #expect(labels.contains("Move to Desktop 5 & follow"))
    }
    private static let desktopFamilies: [SettingKey] = [
        .shortcuts(.focusDesktop),
        .shortcuts(.moveToDesktop),
        .shortcuts(.moveToDesktopFollow),
    ]

    /// Pins every input an expansion reasons from, so a moved
    /// default reds as a default. Two Desktops against three
    /// spaces, deliberately: see `instanceCounts`.
    private func fixture() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            desktops: [1, 2],
            absentDesktops: [],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }
}
