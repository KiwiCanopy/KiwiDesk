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
    /// than a footnote on the others. `reading` names the rung the
    /// binding took (#1609).
    case boundToDesktop(desktop: Int, reading: BoundReading)
    /// A saved profile stores exactly these monitors.
    case exactMonitors(name: String)
    /// No exact set matches; this profile is the screen count's
    /// default.
    case countDefault(name: String)
    /// No saved profile matches; a built-in layout composes.
    /// Carries its stable English `StandardLayout.name`, which
    /// the GUI localizes, and the starter's title when it is the
    /// starter (#1662).
    case builtInStandard(name: String, title: StarterTitle?)
    /// No saved profile matches, and the config is Lua-owned, so
    /// nothing is adopted: a built-in layout steers PLACEMENT
    /// while `activeProfile` (when any) keeps owning the tiling.
    /// A distinct promise from `builtInStandard`, and the GUI
    /// must not say "the built-in X loads" about it.
    case placementOnlyStandard(
        name: String,
        activeProfile: String?,
        title: StarterTitle?
    )
    /// Nothing matches and no built-in plans for this many
    /// screens.
    case none
}

/// What a Desktop binding loads on the connected screens (#1609):
/// the profile, the setup its entry is scoped to — nil for all
/// screen setups — and the profile holding the connected setup
/// that an all-setups pick outranks, nil where none does.
public struct BoundReading: Equatable, Sendable {
    public let name: String
    public let setup: [String]?
    public let over: String?

    public init(name: String, setup: [String]?, over: String?) {
        self.name = name
        self.setup = setup
        self.over = over
    }
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
    /// The active binding is passed in rather than resolved here,
    /// so this stays a pure query over injected state, testable
    /// without a WindowServer. The binding gate reads the display
    /// count from state itself, synchronously with the read
    /// below, so the two cannot differ.
    ///
    /// COST: `match` scans the profile directory and decodes
    /// every profile, so this is a refresh-time query, never a
    /// per-render one. It returns the display count it reasoned
    /// over, so a caller cannot pair the verdict with a second,
    /// later read of the same thing.
    public func profileVerdict(
        activeBinding: DesktopBinding?
    ) -> (verdict: ProfileVerdict, screens: Int) {
        let displays = state.workspaces.allDisplays
        return (
            verdict(activeBinding: activeBinding, displays: displays),
            displays.count
        )
    }

    private func verdict(
        activeBinding: DesktopBinding?,
        displays: [Display]
    ) -> ProfileVerdict {
        // A binding whose profile cannot be read, or is saved for
        // another screen count (#1394), falls THROUGH to matching
        // through the same gate the live doors take — the verdict
        // must not name a profile that would not load.
        //
        // The sentence names the binding's own Mission Control
        // projection, since that is the only name for a Desktop a
        // reader has (#1147). The binding is RESOLVED by the
        // caller — through `mainDesktopBinding`, which asks under
        // both of a Desktop's keys — so this stays a pure query
        // over injected state.
        if let binding = activeBinding,
            let reading = boundReading(of: binding)
        {
            return .boundToDesktop(
                desktop: binding.desktop,
                reading: reading
            )
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

    /// What `binding` loads on the connected screens, and by which
    /// rung (#1609) — nil where the gate stands it aside. The one
    /// reading the verdict and each Desktop row take: both call
    /// this, the verdict over the LIVE binding and a row over its
    /// DRAFT record, so an unsaved edit shows on the row first.
    ///
    /// COST: the gate reads profile files and an all-setups pick
    /// scans them for the holder, so this is a refresh-time query.
    public func boundReading(of binding: DesktopBinding) -> BoundReading? {
        guard case .success(let pick) = boundProfile(of: binding)
        else { return nil }
        let name = pick.profile.name
        if let setup = pick.entry.setup {
            return BoundReading(name: name, setup: setup, over: nil)
        }
        var over: String?
        if case .exact(let holder) = profiles.match(
            fingerprints: liveFingerprints
        ), holder.name != name {
            over = holder.name
        }
        return BoundReading(name: name, setup: nil, over: over)
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
                activeProfile: profiles.currentName,
                title: composed.sourceTitle
            )
        }
        return .builtInStandard(
            name: composed.sourceName,
            title: composed.sourceTitle
        )
    }
}
