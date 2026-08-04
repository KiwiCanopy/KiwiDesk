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
    /// No saved profile matches; a built-in Standard composes.
    /// Carries the Standard's stable English `name`, which the
    /// GUI localizes.
    case builtInStandard(name: String)
    /// Nothing matches and no Standard plans for this many
    /// screens.
    case none
}

extension KiwiCore {
    /// What loads right now, by the same precedence the live
    /// paths use — a binding for the active Desktop first
    /// (`KiwiCore+MonitorChange`: "A native-Space binding wins
    /// over matching (#7)"), then the monitor match, then the
    /// count's Standard.
    ///
    /// The precedence is the whole point of this query existing.
    /// A GUI that asked `profiles.match` alone would answer the
    /// display half of the rule and name the wrong profile on
    /// any machine that binds a Desktop — while the card that
    /// configures those bindings sits on the same page.
    ///
    /// `activeDesktop` is passed in rather than read from
    /// `NativeSpaces` so this stays a pure query over injected
    /// state, testable without a WindowServer.
    ///
    /// COST: `match` scans the profile directory and decodes
    /// every profile, so this is a refresh-time query, never a
    /// per-render one.
    public func profileVerdict(
        activeDesktop: Int?
    ) -> ProfileVerdict {
        // A binding whose profile cannot be read falls THROUGH
        // to matching, exactly as the live path does — the
        // verdict must not name a profile that would fail to
        // load.
        if let desktop = activeDesktop,
            let bound = nativeSpaceBindings[desktop],
            (try? profiles.read(name: bound)) != nil
        {
            return .boundToDesktop(name: bound, desktop: desktop)
        }
        let displays = state.workspaces.allDisplays
        switch profiles.match(
            fingerprints: displays.map(\.fingerprint)
        ) {
        case .exact(let profile):
            return .exactMonitors(name: profile.name)
        case .countDefault(let profile):
            return .countDefault(name: profile.name)
        case .none:
            // The SAME baseline-aware fallback the live path
            // composes with, not `StandardProfiles.standard(for:)`
            // — on the beginner ladder baseline a monitor change
            // recomposes the LADDER (#485), which is
            // `isStandard: false` and so can never be what
            // `standard(for:)` returns. Asking the simpler query
            // would name a workflow Standard while Starter is
            // what actually composes, with the profile header
            // two cards up already saying "Starter".
            guard
                let composed = composeMonitorChangeFallback(
                    displays: displays
                )
            else { return .none }
            return .builtInStandard(name: composed.sourceName)
        }
    }
}
