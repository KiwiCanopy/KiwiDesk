import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a Desktop row whose screen is NOT attached looks like,
/// and where it reaches (#884's verbs, GUI half).
///
/// `DesktopShortcutOfferTests` holds which Desktops are offered;
/// this holds the MARK that keeps that offer honest. Without it
/// a row for an unplugged screen renders identically to a
/// working one and silently does nothing when pressed — in the
/// editor and in the ⌃⌥K panel alike, which is the pair the
/// owner caught on device (2026-08-26).
///
/// `.serialized`, and the locale reset is to `"en"` rather than
/// `nil`: the panel tests compare English, so they move the
/// process-wide `LocalizationManager`, and `nil` means "System
/// default" — the HOST's language — which would hand whatever
/// suite is mid-body a locale nobody chose (tests.md, #740).
@Suite("Desktop away rows", .serialized)
@MainActor
struct DesktopAwayRowTests {
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
            desktops: KeybindingCatalog.DesktopOffer(
                desktops: [1, 2, 5],
                absent: [5]
            ),
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
    /// The ⌃⌥K panel dims an away-Desktop row too, and marks
    /// ONLY that one.
    ///
    /// The panel is a read-only glance surface, so an undimmed
    /// row there is the panel asserting a key works when the
    /// editor one window over says it does not — one concept
    /// looking like two things. Owner caught this on device,
    /// 2026-08-26, against the first cut that dimmed the editor
    /// alone.
    @Test("the panel dims a row whose Desktop is away")
    func panelDimsAnAwayRow() {
        LocalizationManager.shared.select("en")
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+shift+1",
                        lua: "KiwiDesk.focus_desktop(1)",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "ctrl+alt+shift+5",
                        lua: "KiwiDesk.focus_desktop(5)",
                        kind: .navigation
                    ),
                ]
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            // Desktop 5 is bound but NOT live.
            desktops: [1, 2],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        let rows = reference.controls.flatMap(\.rows)
        let away = rows.filter(\.unavailable)
        #expect(away.count == 1)
        #expect(away.first?.label == "Go to Desktop 5")
        // And the live one is NOT dimmed — a mark on every row
        // says as little as a mark on none.
        #expect(
            rows.first { $0.label == "Go to Desktop 1" }?
                .unavailable == false
        )
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
            desktops: KeybindingCatalog.DesktopOffer(desktops: [1, 2]),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }
}
