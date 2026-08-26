import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// WHICH macOS Desktops get a keybinding row (#884's verbs, GUI
/// half).
///
/// The offer is `live ∪ bound`, **per family**: every Desktop
/// that exists, plus every Desktop a binding for THAT family's
/// verb names — so a shortcut survives its screen being
/// unplugged instead of going invisible (#92's argument one noun
/// over), while a binding never conjures a row for a verb the
/// user did not bind.
///
/// `DesktopAwayRowTests` holds what an offered-but-absent row
/// LOOKS like; this holds which Desktops are in the list at all.
/// Split at the §2.1 ceiling.
@Suite("Desktop shortcut offers")
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
            desktops: KeybindingCatalog.DesktopOffer.none,
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
        let focusBinding = KeyBinding(
            combo: "ctrl+alt+5",
            lua: "KiwiDesk.focus_desktop(5)",
            kind: .navigation
        )
        let offer = KeybindingCatalog.desktopOffer(
            live: [1, 2],
            bindings: [focusBinding]
        )
        #expect(offer.focus == [1, 2, 5])
        #expect(offer.absent == [5])
        // And with the bridge absent entirely, the bound one is
        // still the only thing offered — an empty live list is
        // the capability answer, not a reason to drop a row the
        // user authored.
        #expect(
            KeybindingCatalog.desktopOffer(
                live: [],
                bindings: [focusBinding]
            ).focus == [5]
        )
        // A live Desktop the bindings also name is offered once,
        // and is not away.
        let live = KeybindingCatalog.desktopOffer(
            live: [1, 5],
            bindings: [focusBinding]
        )
        #expect(live.focus == [1, 5])
        #expect(live.absent.isEmpty)
    }

    /// **A binding keeps its OWN row alive, and nothing more.**
    ///
    /// The offer was one shared list for a while, so binding
    /// `move_to_desktop(5)` put an unbound "Go to Desktop 5" row
    /// in the Focus card — offering a verb the user never asked
    /// for, on a Desktop that does not exist. Owner found it on
    /// device, 2026-08-26.
    ///
    /// Both directions, because the failure is asymmetric: a
    /// move binding must not reach the focus family, and a focus
    /// binding must not reach the move pair.
    @Test("a binding widens only its own family")
    func aBindingWidensOnlyItsOwnFamily() {
        let moveOnly = KeybindingCatalog.desktopOffer(
            live: [1, 2],
            bindings: [
                KeyBinding(
                    combo: "ctrl+alt+cmd+5",
                    lua: "KiwiDesk.move_to_desktop(5)",
                    kind: .navigation
                )
            ]
        )
        #expect(moveOnly.move == [1, 2, 5])
        #expect(moveOnly.focus == [1, 2])

        let focusOnly = KeybindingCatalog.desktopOffer(
            live: [1, 2],
            bindings: [
                KeyBinding(
                    combo: "ctrl+alt+5",
                    lua: "KiwiDesk.focus_desktop(5)",
                    kind: .navigation
                )
            ]
        )
        #expect(focusOnly.focus == [1, 2, 5])
        #expect(focusOnly.move == [1, 2])
    }

    /// The move PAIR shares one list, whichever half is bound.
    ///
    /// `renderedRows` zips the plain and follow columns and
    /// truncates to the shorter, so a Desktop offered to one and
    /// not the other silently drops rows off the end of BOTH —
    /// including rows for Desktops that are perfectly fine.
    @Test("the move pair always offers the same Desktops")
    func theMovePairStaysInStep() {
        for lua in [
            "KiwiDesk.move_to_desktop(5)",
            "KiwiDesk.move_to_desktop_and_follow(5)",
        ] {
            let offer = KeybindingCatalog.desktopOffer(
                live: [1, 2],
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+cmd+5",
                        lua: lua,
                        kind: .navigation
                    )
                ]
            )
            let expander = ShortcutsFamilyRows(
                spaces: ["1"],
                icons: [:],
                desktops: offer,
                resizeStep: 42,
                layerNames: [KeyLayer.defaultName],
                currentLayer: KeyLayer.defaultName
            )
            let plain =
                expander.rows(for: .shortcuts(.moveToDesktop))
                ?? []
            let follow =
                expander.rows(
                    for: .shortcuts(.moveToDesktopFollow)
                ) ?? []
            #expect(plain.count == follow.count)
            #expect(plain.count == 3)
            // And the interleave keeps every one of them.
            #expect(
                expander.renderedRows(
                    for: .shortcuts(.moveToDesktop)
                ).count == 6
            )
        }
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
            desktops: KeybindingCatalog.DesktopOffer(
                focus: [1, 2],
                move: [1, 2]
            ),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }
}
