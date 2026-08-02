import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts area renders FROM the census (#678 Phase 3):
/// the census owns placement, `ShortcutsRowOrder` owns display
/// order. These pin the two together — every `.shortcuts`-area
/// census key appears in exactly the order list its placement
/// names, so a census row added, retiered or moved without a
/// renderer update is a red test, not a silently missing control.
///
/// Set equality, not sequence: ORDER is the renderer's to own and
/// is deliberately not pinned here, exactly as in
/// `BarsCensusRenderTests` and `ColorsCensusRenderTests`.
@Suite("Shortcuts render ↔ census parity")
struct ShortcutsCensusRenderTests {
    private func censusRows(
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .shortcuts
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    private func pin(
        _ rendered: [SettingKey],
        _ container: SettingsContainer,
        _ tier: SettingTier,
        _ what: Comment
    ) {
        #expect(Set(rendered) == censusRows(container, tier), what)
        #expect(rendered.count == Set(rendered).count, what)
    }

    // MARK: - The action containers

    @Test("Focus renders exactly the census's at-rest families")
    func focusTier() {
        pin(
            ShortcutsRowOrder.focusAtRest,
            .focus,
            .atRest,
            "focus"
        )
        #expect(censusRows(.focus, .showMore).isEmpty)
    }

    @Test("Move windows renders exactly the census's families")
    func moveWindowsTier() {
        pin(
            ShortcutsRowOrder.moveWindowsAtRest,
            .moveWindows,
            .atRest,
            "move windows"
        )
        #expect(censusRows(.moveWindows, .showMore).isEmpty)
    }

    @Test("Size & float's two tiers are the census's")
    func sizeAndFloatTiers() {
        pin(
            ShortcutsRowOrder.sizeAndFloatAtRest,
            .sizeAndFloat,
            .atRest,
            "size & float at rest"
        )
        pin(
            ShortcutsRowOrder.sizeAndFloatMore,
            .sizeAndFloat,
            .showMore,
            "size & float drawer"
        )
    }

    @Test("Open applications renders the census's family")
    func openApplicationsTier() {
        pin(
            ShortcutsRowOrder.openApplicationsAtRest,
            .openApplications,
            .atRest,
            "open applications"
        )
    }

    @Test("General keys renders the census's show-more family")
    func generalKeysTier() {
        pin(
            ShortcutsRowOrder.generalKeysMore,
            .generalKeys,
            .showMore,
            "general keys"
        )
        #expect(censusRows(.generalKeys, .atRest).isEmpty)
    }

    @Test("Layers renders the census's show-more families")
    func layersTier() {
        pin(
            ShortcutsRowOrder.layersMore,
            .layers,
            .showMore,
            "layers"
        )
    }

    @Test("Lua bindings renders the census's show-more families")
    func luaBindingsTier() {
        pin(
            ShortcutsRowOrder.luaBindingsMore,
            .luaBindings,
            .showMore,
            "lua bindings"
        )
    }

    /// The area's render knows exactly these containers; one more
    /// would place rows that mount nowhere, so it must fail loud
    /// here rather than ship an unreachable control.
    ///
    /// `.inactiveShortcuts` is deliberately absent. That card
    /// re-surfaces instances of `goToSpace` / `moveToSpace` whose
    /// space has left the list — the settings are already placed
    /// under Focus and Move windows, and a census row for the
    /// card would be a second placement of a setting that has
    /// one. There is no `SettingsContainer` case for it either,
    /// which is what makes the omission checkable rather than
    /// merely intended.
    @Test("Shortcuts holds exactly the seven rendered containers")
    func shortcutsContainers() {
        #expect(
            containers(of: .shortcuts) == [
                .focus, .moveWindows, .sizeAndFloat,
                .openApplications, .generalKeys, .layers,
                .luaBindings,
            ]
        )
    }

    // MARK: - Families vs instances

    /// The census's unit is a SETTING, and a keybinding family is
    /// one setting however many rows it draws. This is the half
    /// of that rule a type cannot state: every family placed in
    /// the Shortcuts area either expands to rows or is a
    /// hand-drawn container, and none may expand to nothing while
    /// claiming a row tier.
    ///
    /// Pinned against a fixture with a known space list and two
    /// layers, so the per-space and per-layer families expand to
    /// a count this can reason about rather than to whatever the
    /// host happens to have.
    @Test("every row-tier family expands to at least one row")
    @MainActor
    func familiesExpand() {
        let expander = fixture()
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .shortcuts
        }
        #expect(!placed.isEmpty)
        for key in placed {
            guard let rows = expander.rows(for: key) else {
                // A hand-drawn container (the layer strip, the
                // app list, the raw-Lua list) — `nil` is its
                // documented answer, never a missing case.
                continue
            }
            #expect(
                !rows.isEmpty,
                "\(key.id) expands to no rows"
            )
        }
    }

    /// The per-space families expand once per space, and the
    /// switch family once per OTHER layer. A fixture pins both
    /// counts: an expansion that silently collapsed to one row
    /// would still satisfy `familiesExpand`.
    @Test("per-space and per-layer families expand per instance")
    @MainActor
    func instanceCounts() {
        let expander = fixture()
        for key in [
            SettingKey.shortcuts(.goToSpace),
            .shortcuts(.moveToSpace),
            .shortcuts(.moveToSpaceFollow),
        ] {
            #expect(
                expander.rows(for: key)?.count == 3,
                "\(key.id) should expand once per space"
            )
        }
        // Two layers defined, one of them current, so exactly
        // one switch row.
        #expect(
            expander.rows(for: .shortcuts(.switchToLayer))?
                .count == 1
        )
    }

    /// Each per-space family draws its OWN verb. Set equality
    /// over the order list cannot see this: swapping the two
    /// move families' expansions leaves every count identical
    /// and puts "& follow" rows under the plain heading.
    @Test("the two move-to-space families draw different verbs")
    @MainActor
    func moveFamiliesAreDistinct() {
        let expander = fixture()
        let plain =
            expander.rows(for: .shortcuts(.moveToSpace)) ?? []
        let follow =
            expander.rows(for: .shortcuts(.moveToSpaceFollow))
            ?? []
        #expect(!plain.isEmpty && !follow.isEmpty)
        #expect(
            plain.allSatisfy {
                !$0.lua.contains("move_to_space_and_follow")
            }
        )
        #expect(
            follow.allSatisfy {
                $0.lua.contains("move_to_space_and_follow")
            }
        )
    }

    /// The four resize families each draw their own axis and
    /// direction, and each bakes in the live step (#58). Reading
    /// them by name rather than by index into `resizeAndFloat` is
    /// what this pins: an inserted row used to re-point a family
    /// at its neighbour silently.
    @Test("each resize family draws its own axis and direction")
    @MainActor
    func resizeFamiliesAreDistinct() {
        let expander = fixture()
        let expected: [(SettingKey, String)] = [
            (.shortcuts(.growWidth), #"KiwiDesk.resize("x", 42)"#),
            (
                .shortcuts(.shrinkWidth),
                #"KiwiDesk.resize("x", -42)"#
            ),
            (.shortcuts(.growHeight), #"KiwiDesk.resize("y", 42)"#),
            (
                .shortcuts(.shrinkHeight),
                #"KiwiDesk.resize("y", -42)"#
            ),
        ]
        for (key, lua) in expected {
            #expect(expander.rows(for: key)?.first?.lua == lua)
        }
    }

    /// The census key that is NOT a keybinding: Size & float's
    /// drawer row is a `TilingSettings` toggle, so it has no
    /// expansion and the card draws it directly. Pinned because
    /// `nil` here means two different things elsewhere (a
    /// hand-drawn container) and only this one is a non-shortcut.
    @Test("the resize-feedback row carries no keybinding rows")
    @MainActor
    func resizeFeedbackIsNotAFamily() {
        #expect(
            fixture().rows(for: .behaviour(.resizeFeedback))
                == nil
        )
    }

    /// Pins the display-independent inputs every expansion
    /// reasons from, so a default that moves reds as a default
    /// rather than as a mysterious count.
    @MainActor
    private func fixture() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName, "resize"],
            currentLayer: KeyLayer.defaultName
        )
    }

    private func containers(
        of area: SettingsArea
    ) -> Set<SettingsContainer> {
        Set(
            SettingKey.allCases
                .filter { $0.placement.area == area }
                .compactMap { $0.placement.container }
        )
    }
}
