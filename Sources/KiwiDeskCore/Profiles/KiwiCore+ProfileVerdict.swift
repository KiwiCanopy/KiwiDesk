import Foundation

/// Which profile the current machine resolves to, and by which
/// rule (#678 turn 13a).
///
/// Structure, never a sentence — the GUI narrates it
/// (`.claude/rules/core-boundaries.md`). Each case is a different
/// PROMISE, which is why they are not collapsed to a name: an
/// exact monitor set stops matching the moment a fingerprint
/// changes, a count default survives any swap of the same count,
/// and a Standard is not a saved profile at all.
public enum ProfileVerdict: Equatable, Sendable {
    /// A native Desktop binding claims the active Desktop. This
    /// OUTRANKS monitor matching (#7), so it is a case rather
    /// than a footnote on the others.
    case boundToDesktop(name: String, desktop: Int)
    /// A saved profile stores exactly these monitors.
    case exactMonitors(name: String)
    /// No exact set matches; this profile is the screen count's
    /// default.
    case countDefault(name: String)
    /// No saved profile matches; a built-in layout composes.
    /// Carries its stable English `StandardLayout.name`, which
    /// the GUI localizes.
    case builtInStandard(name: String)
    /// No saved profile matches, and the config is Lua-owned, so
    /// nothing is adopted: a built-in layout steers PLACEMENT
    /// while `activeProfile` (when any) keeps owning the tiling.
    /// A distinct promise from `builtInStandard`, and the GUI
    /// must not say "the built-in X loads" about it.
    case placementOnlyStandard(name: String, activeProfile: String?)
    /// Nothing matches and no built-in plans for this many
    /// screens.
    case none
}

extension KiwiCore {
    /// What loads right now, by the same precedence the live
    /// paths use — a binding for the active Desktop first
    /// (`KiwiCore+MonitorChange`: "A native-Space binding wins
    /// over matching (#7)"), then the monitor match, then the
    /// count's built-in layout, which on a Lua-owned config
    /// steers placement only.
    ///
    /// **This query and `handleMonitorChange` read one rule from
    /// two places, so every arm here mirrors an arm there.** Two
    /// copies of a precedence is what drifted in the first
    /// place: the GUI card first asked `ProfileManager.match`
    /// alone and named the wrong profile on a bound Desktop,
    /// then asked `StandardProfiles.standard(for:)` and named a
    /// workflow Standard while the starter setup composed. A
    /// change to the live path's precedence updates this query
    /// in the same change set; `ProfileVerdictTests` fixes each
    /// arm against a fixture built for it.
    ///
    /// The arms are not merged into `handleMonitorChange` itself
    /// because that method APPLIES — it adopts, retiles, marks
    /// dirty and logs — and a Settings card rendering a sentence
    /// must not run any of it. What is shared instead is every
    /// decision input: `read`, `match` and
    /// `composeMonitorChangeFallback` are the same calls, in the
    /// same order, over the same state.
    ///
    /// `activeDesktop` is passed in rather than read from
    /// `NativeSpaces` so this stays a pure query over injected
    /// state, testable without a WindowServer.
    ///
    /// COST: `match` scans the profile directory and decodes
    /// every profile, so this is a refresh-time query, never a
    /// per-render one. It returns the display count it reasoned
    /// over, so a caller cannot pair the verdict with a second,
    /// later read of the same thing.
    public func profileVerdict(
        activeDesktop: Int?
    ) -> (verdict: ProfileVerdict, screens: Int) {
        let displays = state.workspaces.allDisplays
        return (
            verdict(activeDesktop: activeDesktop, displays: displays),
            displays.count
        )
    }

    private func verdict(
        activeDesktop: Int?,
        displays: [Display]
    ) -> ProfileVerdict {
        // A binding whose profile cannot be read falls THROUGH
        // to matching, exactly as the live path does — the
        // verdict must not name a profile that would fail to
        // load.
        if let desktop = activeDesktop,
            let bound = desktopBindings[desktop],
            (try? profiles.read(name: bound)) != nil
        {
            return .boundToDesktop(name: bound, desktop: desktop)
        }
        switch profiles.match(
            fingerprints: displays.map(\.fingerprint)
        ) {
        case .exact(let profile):
            return .exactMonitors(name: profile.name)
        case .countDefault(let profile):
            return .countDefault(name: profile.name)
        case .none:
            return fallbackVerdict(displays: displays)
        }
    }

    /// The `.none` arm, mirroring `handleMonitorChange`'s: the
    /// baseline-aware fallback (the starter setup while on the
    /// Starter baseline, else the count's Standard), and then the
    /// `isGuiManaged` split that decides whether the composed
    /// layout is ADOPTED or merely steers placement.
    private func fallbackVerdict(
        displays: [Display]
    ) -> ProfileVerdict {
        guard
            let composed = composeMonitorChangeFallback(
                displays: displays
            )
        else { return .none }
        guard isGuiManaged else {
            return .placementOnlyStandard(
                name: composed.sourceName,
                activeProfile: profiles.currentName
            )
        }
        return .builtInStandard(name: composed.sourceName)
    }
}
