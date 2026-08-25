import KiwiDeskCore

/// The Profiles area's greying, resolved from the census (#678
/// Phase 3, turn 13a). Keyed on a row's own `SettingKey` and
/// returning a REASON case rather than a Bool — the shape the
/// other census areas already share, so this area adds no new
/// resolver signature.
///
/// PER INSTANCE, like `SpacesGates`: the preset rows each ask
/// about their own screen count, so the context carries the
/// preset's count alongside the live one. It answers only ROW
/// gates — no container in this area carries a
/// `SettingsContainer.gate` — and it takes no `SettingsMode`
/// input: the mode never changes what runs (8c).
///
/// **The census names every arm.** Apply is dead on a
/// screen-count mismatch AND while a stored profile is being
/// edited (applying a preset switches the LIVE layout, which
/// editing a stored profile never does), so it declares
/// `.runtimeAnyOf`; the bindings die only while a stored profile
/// is being edited — #888 retired the separate-Spaces arm by
/// giving the trigger a definition that holds in every display
/// mode (the MAIN display's Desktop), so that row is back to one
/// arm. The resolver owns the whole predicate either way. The
/// reasons stay APART here because their sentences differ and
/// only some name a fix.
///
/// Returning the reason rather than a Bool keeps the grey and its
/// inline sentence from being two decisions that can disagree
/// (`ProfilesGateHelp` renders it), and keeps the whole resolver
/// assertable off the main actor.
struct ProfilesGates {
    /// Whether the dashboard is editing a stored profile rather
    /// than the live config (#18).
    let editingStoredProfile: Bool
    /// How many screens are connected right now.
    let connectedScreens: Int
    /// The preset row's OWN screen count. nil on every other
    /// row — a `presetsApply` resolve with nil is a caller that
    /// forgot to pass it, which asserts rather than silently
    /// greying (or silently not greying) the card.
    var presetScreens: Int?

    /// Why a row is inert. One case per predicate AND per
    /// sentence: the two rows that die while a stored profile is
    /// edited die for visibly different reasons, so they are two
    /// cases rather than one case with a branchy sentence.
    enum InertReason: Hashable {
        /// Desktop bindings are global — a stored profile may
        /// never override what SELECTS it.
        case bindingsAreGlobal
        /// Applying a preset switches the live layout.
        case presetSwitchesLiveLayout
        /// The preset plans for a different screen count.
        case screenCountMismatch(screens: Int)
    }

    /// Why `key`'s row is inert right now, or nil while it is
    /// live. Fail-OPEN on a gate this type does not own — loud in
    /// debug, live in release — matching the other area
    /// resolvers: of the two silent readings, a live row the user
    /// can ignore beats a dead one they cannot explain.
    /// `everyGatedRowIsResolved` keeps that arm unreachable
    /// rather than merely believed to be.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .profiles(.profileBindings):
            return editingStoredProfile
                ? .bindingsAreGlobal : nil
        case .profiles(.presetsApply):
            if editingStoredProfile {
                return .presetSwitchesLiveLayout
            }
            guard let screens = presetScreens else {
                assertionFailure(
                    "presetsApply resolved without a preset "
                        + "screen count"
                )
                return nil
            }
            return screens == connectedScreens
                ? nil : .screenCountMismatch(screens: screens)
        default:
            assertionFailure(
                "unhandled Profiles gate: \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers. Data, so
    /// `everyGatedRowIsResolved` reds when a new census gate in
    /// this area lands in neither set instead of hitting the
    /// fail-open default at run time.
    static let resolved: Set<SettingKey> = [
        .profiles(.profileBindings),
        .profiles(.presetsApply),
    ]

    /// Declared-but-answered-elsewhere. Empty and kept so a new
    /// gate this resolver cannot answer must land here on purpose
    /// rather than pass silently.
    static let resolvedElsewhere: Set<SettingKey> = []
}

/// The inline sentence each `ProfilesGates.InertReason` renders —
/// the "why you can't use this" a greyed row shows on hover.
/// Split from the resolver so the resolver stays assertable off
/// the main actor; the reason and its sentence are one decision,
/// never two that can disagree (#678, gui.md).
///
/// Every key is reused verbatim from the hand-wired gate this
/// conversion replaced, so their English is unchanged and no
/// translation of them is dropped. (The conversion's fourth key,
/// `desktops.separate_warning`, retired with #888 — the
/// separate-Spaces state no longer greys the rows at all.)
@MainActor
enum ProfilesGateHelp {
    static func sentence(
        for reason: ProfilesGates.InertReason
    ) -> String {
        switch reason {
        case .bindingsAreGlobal:
            return L(
                "profiles.desktops.live_only",
                "Desktop bindings are global — switch to "
                    + "Live to change them."
            )
        case .presetSwitchesLiveLayout:
            return L(
                "presets.editing_stored",
                "Applying a preset switches your live layout, "
                    + "which editing a saved profile never does. "
                    + "Switch to Live to apply one."
            )
        case .screenCountMismatch(let screens):
            return L(
                "presets.needs_screens",
                "Needs %1$d connected screen(s).",
                screens
            )
        }
    }
}
