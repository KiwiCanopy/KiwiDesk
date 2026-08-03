import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts area renders FROM the census (#678 Phase 3):
/// the census owns placement, `ShortcutsRowOrder` owns display
/// order. These pin the two together — every `.shortcuts`-area
/// census key appears in exactly the order list its placement
/// names, so a census row added, retiered or moved without a
/// renderer update is a red test.
///
/// **The promise is weaker for three containers**, and reading
/// it as unqualified is how a control ships invisible: the app
/// list, the layer strip and the raw-Lua drawer are bespoke
/// views, so their lists guard membership and nothing checks
/// that a family added to one reaches the screen. Which three
/// is data (`ShortcutsRowOrder.bespokeContainers`), asserted by
/// `bespokeContainersAreDeclared`.
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

    /// Bespoke container — membership only (see the suite note).
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

    /// `.immediate`, not `.showMore`: a configured layer is the
    /// user's own setup, so the card surfaces at rest the moment
    /// one exists (config presence expands the simple surface).
    /// Reading these as show-more hides a user's configuration
    /// from them, which an earlier draft of this area did.
    /// Bespoke container — membership only (see the suite note).
    @Test("Layers renders the census's immediate families")
    func layersTier() {
        pin(
            ShortcutsRowOrder.layersMore,
            .layers,
            .immediate,
            "layers"
        )
        #expect(censusRows(.layers, .showMore).isEmpty)
        #expect(censusRows(.layers, .atRest).isEmpty)
    }

    /// Two tiers in one container: the raw-Lua rows hide behind
    /// the Advanced drawer, while Import draws at rest in the
    /// header — the affordance a new user needs, kept absent
    /// until `init.lua` holds something to adopt by its runtime
    /// gate rather than by a disclosure.
    /// Bespoke container — membership only (see the suite note).
    @Test("Lua bindings splits across its two census tiers")
    func luaBindingsTier() {
        pin(
            ShortcutsRowOrder.luaBindingsMore,
            .luaBindings,
            .showMore,
            "lua bindings drawer"
        )
        pin(
            ShortcutsRowOrder.luaBindingsAtRest,
            .luaBindings,
            .atRest,
            "import row"
        )
    }

    /// Which containers are drawn by bespoke views is DERIVED
    /// from the source, not restated here.
    ///
    /// An earlier draft compared the declared set to a literal
    /// copy of itself, which reds only when someone edits the
    /// set — the very action it exists to compel — and stays
    /// green on the failure it names: a container quietly going
    /// bespoke with the set untouched. `gui.md` claimed it was
    /// enforced, so the claim had to become true or go.
    ///
    /// The signal is the renderer's own shape: a census-driven
    /// container's order list is walked by a `ForEach` somewhere
    /// under `Sources/KiwiDesk`; a bespoke one's is read only by
    /// this suite. So the scan asks which `ShortcutsRowOrder`
    /// lists appear inside a `ForEach(` and maps them back to
    /// their containers.
    @Test("bespoke containers are the ones no ForEach walks")
    func bespokeContainersAreDeclared() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var rendered = ""
        for file in try SourceScan.swiftSources(under: root) {
            rendered += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        // Each order list, and the container it serves.
        let lists: [(String, SettingsContainer)] = [
            ("focusAtRest", .focus),
            ("moveWindowsAtRest", .moveWindows),
            ("sizeAndFloatAtRest", .sizeAndFloat),
            ("sizeAndFloatMore", .sizeAndFloat),
            ("generalKeysMore", .generalKeys),
            ("openApplicationsAtRest", .openApplications),
            ("layersMore", .layers),
            ("luaBindingsMore", .luaBindings),
            ("luaBindingsAtRest", .luaBindings),
        ]
        // Vacuity: the scan must have read something, and every
        // list named must exist in the source it read.
        #expect(!rendered.isEmpty)
        for (name, _) in lists {
            #expect(
                rendered.contains("ShortcutsRowOrder.\(name)")
                    || rendered.contains("static let \(name)"),
                Comment(rawValue: "unknown order list \(name)")
            )
        }
        var walked: Set<SettingsContainer> = []
        for (name, container) in lists
        where isWalked(name, in: rendered) {
            walked.insert(container)
        }
        let all = Set(lists.map(\.1))
        #expect(
            ShortcutsRowOrder.bespokeContainers
                == all.subtracting(walked)
        )
        #expect(
            ShortcutsRowOrder.bespokeContainers
                .isSubset(of: containers(of: .shortcuts))
        )
    }

    /// Whether a `ForEach(` anywhere in `source` walks the named
    /// order list. Matched within the `ForEach`'s own balanced
    /// parentheses so an unrelated mention nearby cannot count.
    private func isWalked(
        _ list: String,
        in source: String
    ) -> Bool {
        let characters = Array(source)
        let needle = Array("ForEach")
        var index = 0
        while index + needle.count < characters.count {
            guard
                Array(
                    characters[index..<(index + needle.count)]
                ) == needle
            else {
                index += 1
                continue
            }
            var cursor = index + needle.count
            let body = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            )
            if body?.contains("ShortcutsRowOrder.\(list)")
                == true
            {
                return true
            }
            index += needle.count
        }
        return false
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
    ///
    /// One direction only, and knowingly: this reds on a
    /// container appearing in the census that nothing mounts, not
    /// on a card deleted from `ShortcutsSection` while its census
    /// rows and order list stay. Closing the other half needs the
    /// renderer to publish its mounted containers as data, which
    /// no area does yet — until one does, a deleted card is a
    /// reviewer's catch.
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
