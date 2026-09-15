import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The half a source scan cannot reach: what the offer's two
/// predicates RESOLVE to. Inverting `hasRows` deleted all twelve
/// Desktop rows from both cards with every needle, the census
/// parity and the resolver suite green — a positive substring
/// names the branch, never the predicate inside it
/// (guard-prover, 2026-09-04). Internal-not-private is gui.md's
/// instrument for exactly this, taken from the schematics.
///
/// Main-actor spend (tests.md): two `makeTestModel` builds and
/// one `ShortcutsFamilyRows` fixture. No source scan, no
/// filesystem walk, no AppKit measurement.
@MainActor
@Suite("Desktop shortcuts offer predicates")
struct ShortcutsDesktopOfferPredicateTests {
    private func expander(
        desktops: [Int]
    ) -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: [],
            icons: [:],
            desktops: .init(desktops: desktops),
            resizeStep: 40,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }

    private func offer(
        desktops: [Int],
        bindings: [KeyBinding] = []
    ) -> DesktopShortcutsOffer {
        let model = makeTestModel()
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            )
        ]
        return DesktopShortcutsOffer(
            model: model,
            bindings: .constant(bindings),
            keys: ShortcutsRowOrder.focusDesktopFamilies,
            drawer: SettingsCatalog.shortcuts.focusDesktops,
            expander: expander(desktops: desktops)
        )
    }

    @Test("the door opens on rows, and stays shut over none")
    func hasRowsFollowsTheFamilies() {
        #expect(offer(desktops: [1, 2]).hasRows)
        // No bridge and nothing bound: the families expand to
        // nothing, so the offer withholds itself entirely
        // rather than opening on an empty drawer.
        #expect(!offer(desktops: []).hasRows)
    }

    @Test("bound follows a recorded Desktop binding")
    func boundFollowsTheBinding() {
        #expect(!offer(desktops: [1, 2]).bound)
        #expect(
            offer(
                desktops: [1, 2],
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+1",
                        lua: "KiwiDesk.focus_desktop(1)",
                        kind: .navigation
                    )
                ]
            ).bound
        )
        // A bound Desktop the bridge cannot see keeps its row:
        // `desktopOffer` unions the bound numbers into the live
        // ones. Asserted at the source rather than through the
        // fixture, because #1125 taught that offer to filter on
        // a RECORDED combo and an away row must survive it.
        let away = KeyBinding(
            combo: "ctrl+alt+9",
            lua: "KiwiDesk.focus_desktop(9)",
            kind: .navigation
        )
        let offered = KeybindingCatalog.desktopOffer(
            live: [],
            bindings: [away]
        )
        #expect(offered.desktops == [9])
        #expect(offered.absent == [9])
        #expect(offer(desktops: [], bindings: [away]).bound)
        // …while an UNRECORDED row offers no Desktop at all, so
        // the filter #1125 added there cannot be dropped
        // silently: the gate and the offer answer alike.
        var blank = away
        blank.combo = ""
        #expect(
            KeybindingCatalog.desktopOffer(
                live: [],
                bindings: [blank]
            )
            .desktops.isEmpty
        )
        #expect(!offer(desktops: [], bindings: [blank]).bound)
    }
}

/// The door's own reachability (#1125). The census path refuses
/// a bridge-gated ROW at `indexes` (`StickyReachRowTests`), but
/// a catalog declaration carries no gate and reaches the index
/// through `extras`, which filtered nothing — so search returned
/// the door to a capability the Mac has none of, and deleting
/// the fix left the whole suite green (guard-prover,
/// 2026-09-04).
///
/// Main-actor spend (tests.md): two index builds over the
/// catalog, each dropping the locale-keyed cache through the
/// `canDriveDesktops` setter. No source scan, no filesystem walk.
@MainActor
@Suite("Desktop offer search reachability")
struct ShortcutsDesktopOfferSearchTests {
    private func doorIDs() -> Set<String> {
        [
            SettingsCatalog.shortcuts.focusDesktops.control.id,
            SettingsCatalog.shortcuts.moveWindowsDesktops.control
                .id,
        ]
    }

    private func indexedDoors() -> Set<String> {
        Set(
            SettingsSearchIndex.rows()
                .compactMap(\.anchor.anchor)
        )
        .intersection(doorIDs())
    }

    @Test("the doors are offered only where they lead somewhere")
    func doorsFollowTheBridge() {
        LocalizationManager.shared.select("en")
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }

        SettingsSearchIndex.canDriveDesktops = true
        #expect(
            indexedDoors() == doorIDs(),
            "both doors are search rows where the bridge exists"
        )
        SettingsSearchIndex.canDriveDesktops = false
        #expect(
            indexedDoors().isEmpty,
            Comment(
                rawValue: "a door indexed on a Mac that draws "
                    + "neither offer lands on nothing"
            )
        )
        // The register is what the filter reads, so an emptied
        // one is the same defect wearing a different shape.
        #expect(
            SettingsSearchIndex.bridgeGatedControls == doorIDs()
        )
    }
}
