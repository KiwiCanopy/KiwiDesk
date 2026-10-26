import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The half a source scan cannot reach: what the macOS Desktops
/// section's predicates RESOLVE to (#2655). Inverting the drawer's
/// `hasRows` once deleted every Desktop row with every needle, the
/// census parity and the resolver suite green — a positive
/// substring names the branch, never the predicate inside it
/// (guard-prover, 2026-09-04).
///
/// Main-actor spend (tests.md): a few `makeTestModel` builds and
/// `ShortcutsFamilyRows` fixtures. No source scan, no filesystem
/// walk, no AppKit measurement.
@MainActor
@Suite("macOS Desktops section predicates")
struct MacOSDesktopsPredicateTests {
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

    private func group(
        bindings: [KeyBinding] = []
    ) -> MacOSDesktopsGroup {
        let model = makeTestModel()
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            )
        ]
        return MacOSDesktopsGroup(
            model: model,
            bindings: .constant(bindings),
            expander: expander(desktops: [1, 2])
        )
    }

    private func binding(_ lua: String) -> KeyBinding {
        KeyBinding(combo: "ctrl+alt+1", lua: lua, kind: .navigation)
    }

    @Test("the section draws over rows, and is removed over none")
    func hasRowsFollowsTheFamilies() {
        #expect(MacOSDesktopsGroup.hasRows(expander(desktops: [1, 2])))
        #expect(
            MacOSDesktopsGroup.movesHaveRows(
                expander(desktops: [1, 2])
            )
        )
        // No bridge and nothing bound: the families expand to
        // nothing, so the section is removed rather than greyed.
        #expect(!MacOSDesktopsGroup.hasRows(expander(desktops: [])))
        #expect(
            !MacOSDesktopsGroup.movesHaveRows(expander(desktops: []))
        )
    }

    /// Go to Desktop is seeded on every install, so it must not
    /// open the drawer; only a move does.
    @Test("the drawer opens on a bound move, never on Go to")
    func movesBoundFollowsAMove() {
        #expect(!group().movesBound)
        #expect(
            !group(bindings: [binding("KiwiDesk.focus_desktop(1)")])
                .movesBound
        )
        #expect(
            group(bindings: [binding("KiwiDesk.move_to_desktop(2)")])
                .movesBound
        )
        #expect(
            group(bindings: [
                binding("KiwiDesk.move_to_desktop_and_follow(3)")
            ])
            .movesBound
        )
        // A Space verb is not a Desktop verb.
        #expect(
            !group(bindings: [binding("KiwiDesk.move_to_space('1')")])
                .movesBound
        )
        // An UNRECORDED row is not a binding.
        var blank = binding("KiwiDesk.move_to_desktop(2)")
        blank.combo = ""
        #expect(!group(bindings: [blank]).movesBound)
    }

    /// The hold-open is the area's, not the layer's: a move bound
    /// in another layer opens the drawer while this one is edited.
    @Test("a move bound in any layer opens the drawer")
    func movesBoundCountsAcrossLayers() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(
                name: "media",
                bindings: [binding("KiwiDesk.move_to_desktop(3)")]
            ),
        ]
        #expect(ShortcutsGates(config: config).desktopMovesBound)
    }
}

/// The section's own reachability (#1125, #2655). The census path
/// refuses a bridge-gated ROW at `indexes` (`StickyReachRowTests`),
/// but a catalog declaration carries no gate and reaches the index
/// through `extras` — so without the register search returned the
/// door to a capability the Mac has none of (guard-prover,
/// 2026-09-04).
///
/// Main-actor spend (tests.md): two index builds over the
/// catalog, each dropping the locale-keyed cache through the
/// `canDriveDesktops` setter. No source scan, no filesystem walk.
@MainActor
@Suite("macOS Desktops search reachability")
struct MacOSDesktopsSearchTests {
    private func doorIDs() -> Set<String> {
        [
            SettingsCatalog.shortcuts.desktopsSection.id,
            SettingsCatalog.shortcuts.desktopMoves.control.id,
        ]
    }

    private func indexedDoors() -> Set<String> {
        Set(
            SettingsSearchIndex.rows()
                .compactMap(\.anchor.anchor)
        )
        .intersection(doorIDs())
    }

    @Test("the section is offered only where it leads somewhere")
    func doorsFollowTheBridge() {
        LocalizationManager.shared.select("en")
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }

        SettingsSearchIndex.canDriveDesktops = true
        #expect(
            indexedDoors() == doorIDs(),
            "both names are search rows where the bridge exists"
        )
        SettingsSearchIndex.canDriveDesktops = false
        #expect(
            indexedDoors().isEmpty,
            Comment(
                rawValue: "a name indexed on a Mac that draws "
                    + "no section lands on nothing"
            )
        )
        // The register is what the filter reads, so an emptied
        // one is the same defect wearing a different shape.
        #expect(
            SettingsSearchIndex.bridgeGatedControls == doorIDs()
        )
    }

    /// The switch cue is a census row inside the section, so it
    /// is refused at `indexes` on the same bridge question — a
    /// hit for it would land on a section nothing draws.
    @Test("the switch cue is indexed only where its section draws")
    func cueFollowsTheBridge() {
        LocalizationManager.shared.select("en")
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        func indexed() -> Bool {
            SettingsSearchIndex.rows().contains {
                $0.key == .shortcuts(.desktopCue)
            }
        }
        SettingsSearchIndex.canDriveDesktops = true
        #expect(indexed())
        SettingsSearchIndex.canDriveDesktops = false
        #expect(!indexed())
    }
}
