import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Profiles gate resolver (#678 Phase 3, turn 13a).
///
/// A census `gate:` is answered by the resolver and never
/// re-implemented beside its row: a renderer whose predicate
/// drifts from the declaration greys the wrong row, and the
/// census's stated owner quietly stops being the owner. These pin
/// each declared gate against a state that satisfies it and one
/// that does not — and pin that the declared set and the resolved
/// set are the same set, so a new gated row cannot land in
/// neither.
///
/// The row with TWO reasons is the case to watch. `presetsApply`
/// declares one gate and dies for two independent reasons, and
/// the stored-profile one WINS: a user editing a stored profile
/// on matching hardware must not read "Needs 3 connected
/// screen(s)" while three are connected.
@Suite("Profiles gates")
struct ProfilesGateTests {
    private func gates(
        editing: Bool = false,
        screens: Int = 3,
        preset: Int? = nil
    ) -> ProfilesGates {
        ProfilesGates(
            editingStoredProfile: editing,
            connectedScreens: screens,
            presetScreens: preset
        )
    }

    /// The declared-vs-answered split, read off the census: a new
    /// gated ROW in this area that lands in neither set reds here
    /// rather than failing open at run time.
    @Test("every gated row in the area is accounted for")
    func everyGatedRowIsResolved() {
        let declared = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .profiles
                    && $0.placement.gate != nil
            }
        )
        #expect(
            declared
                == ProfilesGates.resolved.union(
                    ProfilesGates.resolvedElsewhere
                )
        )
        // Both halves pinned, not just their union — an entry
        // parked in `resolvedElsewhere` that the resolver
        // actually answers would claim the opposite of what it
        // does. Trivially true while `resolvedElsewhere` is
        // empty: a slot armed for its first entry, not a live
        // net.
        #expect(
            ProfilesGates.resolved
                .intersection(ProfilesGates.resolvedElsewhere)
                .isEmpty
        )
    }

    /// A `.runtimeAnyOf` names the arms it stands for — every
    /// one of them, and more than one.
    ///
    /// Nothing else reads a gate's PAYLOAD: `everyGatedRowIsResolved`
    /// only asks `gate != nil`, so `.runtimeAnyOf([])` — a row
    /// declaring a compound gate that names nothing — passed the
    /// whole suite (guard-prover, 2026-08-04). That is the exact
    /// failure the case was introduced to prevent, since a gate
    /// naming no condition records less than the single tag it
    /// replaced.
    ///
    /// Repo-wide, not area-scoped: the case is census vocabulary,
    /// and the second area to use it inherits this guard rather
    /// than writing its own.
    @Test("a compound runtime gate names at least two arms")
    func compoundGatesNameTheirArms() {
        var compound = 0
        for key in SettingKey.allCases {
            guard
                case .runtimeAnyOf(let conditions) =
                    key.placement.gate
            else { continue }
            compound += 1
            #expect(
                conditions.count > 1,
                Comment(
                    rawValue:
                        "\(key.id) declares a compound gate "
                        + "naming \(conditions.count) "
                        + "condition(s) — one arm or none is a "
                        + "plain `.runtime`, or a gate that "
                        + "records nothing"
                )
            )
            #expect(
                Set(conditions).count == conditions.count,
                "\(key.id) names a condition twice"
            )
        }
        // Vacuity: the sweep must have found the row it is
        // about, or every check above held over nothing.
        // (`profileBindings` left the compound set with #888 —
        // its separate-Spaces arm retired, so it is a plain
        // `.runtime` again and `presetsApply` is the one left.)
        #expect(compound == 1)
    }

    /// No container in this area carries a gate, so the resolver
    /// answers only ROW gates — a CONTAINER gate here would grey
    /// a whole card with nothing to resolve it, since this
    /// resolver has no `containerReason` arm. Data, so it reds
    /// the day one is added rather than at a reviewer's
    /// discretion.
    @Test("the area carries no container gate")
    func noContainerGate() {
        let gatedContainers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .profiles }
                .compactMap { $0.placement.container }
                .filter { $0.gate != nil }
        )
        #expect(gatedContainers.isEmpty)
    }

    // MARK: - Desktop bindings

    @Test("bindings are live while editing the live config")
    func bindingsLive() {
        #expect(
            gates().inertReason(
                for: .profiles(.profileBindings)
            ) == nil
        )
    }

    @Test("editing a stored profile kills the bindings")
    func bindingsEditingStored() {
        #expect(
            gates(editing: true).inertReason(
                for: .profiles(.profileBindings)
            ) == .bindingsAreGlobal
        )
    }

    // #888 retired the separate-Spaces arm: a binding names one
    // event in every display mode (the main display's Desktop),
    // so no display state greys these rows any more —
    // `bindingsLive` above is what holds them live.

    // MARK: - Preset apply

    @Test("a preset for the connected count applies")
    func presetMatching() {
        #expect(
            gates(screens: 3, preset: 3).inertReason(
                for: .profiles(.presetsApply)
            ) == nil
        )
    }

    /// The reason carries the count the preset needs, not the
    /// one connected — the sentence tells the user what to plug
    /// in.
    @Test("a preset for another count names that count")
    func presetMismatch() {
        #expect(
            gates(screens: 3, preset: 1).inertReason(
                for: .profiles(.presetsApply)
            ) == .screenCountMismatch(screens: 1)
        )
    }

    /// Both fixtures, because only the second pins the
    /// PRECEDENCE this test is named for: with the counts equal
    /// the mismatch branch never fires, so reordering the arms
    /// leaves the first `#expect` green (guard-prover, 2026-08-04).
    /// The mismatched one is also the case that matters on
    /// screen — a user editing a stored profile must not read
    /// "Needs 1 connected screen(s)" when connecting that screen
    /// would change nothing.
    @Test("editing a stored profile outranks any count verdict")
    func presetEditingStored() {
        #expect(
            gates(editing: true, screens: 3, preset: 3)
                .inertReason(for: .profiles(.presetsApply))
                == .presetSwitchesLiveLayout
        )
        #expect(
            gates(editing: true, screens: 3, preset: 1)
                .inertReason(for: .profiles(.presetsApply))
                == .presetSwitchesLiveLayout
        )
    }

    /// An ungated key resolves to nil without reaching the
    /// switch at all — the `placement.gate` guard, which is what
    /// lets every renderer call the resolver unconditionally.
    ///
    /// Stated limit: dropping that guard trips the resolver's
    /// `assertionFailure`, so this reds as a DEBUG trap (which
    /// takes the runner's process with it), not as a failed
    /// expectation. A release build would reach the fail-open
    /// `default` arm and pass — deliberately, since fail-open is
    /// what a shipped Settings window wants, and the debug trap
    /// is what a developer wants.
    @Test("an ungated row is never inert")
    func ungatedRow() {
        #expect(
            gates().inertReason(for: .profiles(.profilesLoad))
                == nil
        )
    }
}
