import CoreGraphics
import KiwiDeskCore

/// One instance a Profiles census key expands into (#678 Phase 3,
/// turn 13a).
///
/// Every container in this area draws a row per live thing rather
/// than a row per setting, so the instance carries the thing's
/// identity — which is what a guard can compare, and what set
/// equality over `SettingKey` alone cannot see.
enum ProfilesRowInstance: Hashable {
    /// One saved profile, by name.
    case profile(String)
    /// One native macOS Desktop, by Mission Control number.
    case desktop(Int)
    /// One built-in preset, by its stable English
    /// `StandardLayout.name` (never the localized display name —
    /// identity must not move with the GUI language).
    case preset(String)
}

/// Expands a Profiles census key into the rows it renders (#678
/// Phase 3, turn 13a).
///
/// The census records settings, not rows: `profilesLoad` is one
/// case and puts one button on every saved profile's row,
/// `profileBindings` one case and one row per Desktop. That is
/// the same asymmetry the Shortcuts area met first, and it needs
/// the same second seam — `ProfilesRowOrder` answers *where does
/// this key sit*, this answers *what does it draw*, and
/// `ProfilesCensusRenderTests` pins each against the census
/// independently.
///
/// The switch is exhaustive over `ProfilesKey` on purpose: a key
/// added to the census fails to compile here until it is given an
/// expansion, which is a stronger net than the render guard alone.
///
/// A key with no rows of its own returns `nil` — and WHICH keys
/// may answer it is enumerated in `ProfilesCensusRenderTests`
/// rather than counted here, because a renderer reading
/// `rows(for:) ?? []` cannot tell a key that never draws from one
/// whose rows disappeared.
struct ProfilesFamilyRows {
    /// The saved profiles, unordered — `orderedProfiles` is what
    /// puts them in display order, and it is the same call the
    /// list makes.
    let profiles: [ProfileSummary]
    /// How many native Desktops are detected right now.
    let presentDesktops: Int
    /// Desktop numbers a binding already names, so one to a
    /// now-absent Space stays listed.
    let boundDesktops: [Int]
    /// The presets the area offers, in catalog order.
    let presets: [StandardLayout]
    /// How many screens are connected right now — the second sort
    /// key's input. Read from `ProfileResolution.screens` rather
    /// than from a fresh `displays.count`, so this and
    /// `matchesLive` are answers about the same moment.
    let connectedScreens: Int

    func rows(for key: SettingKey) -> [ProfilesRowInstance]? {
        guard case .profiles(let family) = key else { return nil }
        return rows(for: family)
    }

    /// The saved profiles the list draws, in display order: the
    /// ones matching the connected displays first — the card's
    /// caption promises one of them loads — then the ones whose
    /// screen COUNT matches, then by screen count, then by name,
    /// so the order is stable while nothing is plugged or
    /// unplugged.
    ///
    /// The count key exists because the first key is a
    /// FINGERPRINT match and the third is a bare number, and a
    /// profile can be neither: on a two-screen desk a saved
    /// two-screen profile for different monitors sorted behind
    /// every one-screen profile, since 1 < 2 — under a caption
    /// promising one of them loads. It sits SECOND rather than
    /// first because a fingerprint match is a stronger claim than
    /// an equal count, and `matchesLive` already implies the
    /// count matches, so the two keys never disagree on one row.
    ///
    /// `connectedScreens: 0` — no display read yet — makes the
    /// key inert rather than wrong: no saved profile declares
    /// zero screens, so nothing matches and the order falls back
    /// to what it was before this key existed.
    ///
    /// The ORDER lives here, with the expansion, rather than in
    /// the view, so the rule is stated once and is reachable
    /// from a test (`ProfilesFamilyRowsTests`); that the views
    /// actually call it is
    /// `ProfilesGateWiringTests.viewsConsultTheFamilySeam`.
    /// Note which guard holds which: `rows(for:)` and its census
    /// parity are held over fixtures, and it is this static half
    /// the screen consumes — including
    /// `ProfilesSection.neighbourAfterDeleting`, whose focus
    /// destination IS this order.
    static func orderedProfiles(
        _ summaries: [ProfileSummary],
        connectedScreens: Int
    ) -> [ProfileSummary] {
        func key(
            _ summary: ProfileSummary
        ) -> (Int, Int, Int, String) {
            (
                summary.matchesLive ? 0 : 1,
                summary.count == connectedScreens ? 0 : 1,
                summary.count,
                summary.name
            )
        }
        return summaries.sorted { key($0) < key($1) }
    }

    /// The Desktops the bindings card lists: every present
    /// desktop plus any number already bound, so a binding to a
    /// now-absent Space stays visible and clearable rather than
    /// silently lost.
    static func desktops(
        present: Int,
        bound: some Collection<Int>
    ) -> [Int] {
        let live = present > 0 ? Array(1...present) : []
        return Array(Set(live).union(bound)).sorted()
    }

    /// The presets a screen count offers, in catalog order.
    ///
    /// `sizes` are the LIVE screens, which the `Starter` entry is
    /// derived from (#678 Phase 4 pass 11). It follows that the
    /// drawer below offers no Starter at all: a count you are not
    /// running has no screen shapes to choose layouts from, so
    /// "For other setups" is the workflow layouts alone.
    static func presets(
        forScreens screens: Int,
        sizes: [CGSize]
    ) -> [StandardLayout] {
        StandardProfiles.layouts(for: screens, sizes: sizes)
    }

    /// Every preset for a count that is NOT connected — the
    /// "For other setups" drawer's contents.
    static func presets(
        excludingScreens screens: Int
    ) -> [StandardLayout] {
        StandardProfiles.workflows.filter {
            $0.screenCount != screens
        }
    }

    /// Both halves of the seam answer from ONE derivation.
    ///
    /// The static helpers ABOVE are what the three containers
    /// call; this expansion is what the census guards read, and
    /// it reaches those same statics rather than re-deriving
    /// beside them. An earlier cut computed the two separately
    /// from the same inputs, which made `familiesExpand` and
    /// `instanceCounts` assert over a structure the screen never
    /// touched — the dead seam moved rather than removed. The
    /// join is proved, not asserted: mutating `orderedProfiles`
    /// reds `ProfilesFamilyRowsTests` AND
    /// `ProfilesCensusRenderTests.instanceCounts` together
    /// (guard-prover, 2026-08-04).
    private func rows(
        for family: ProfilesKey
    ) -> [ProfilesRowInstance]? {
        switch family {
        case .profilesLoad, .profilesDelete, .profilesRename,
            .isDefault:
            return Self.orderedProfiles(
                profiles,
                connectedScreens: connectedScreens
            )
            .map { ProfilesRowInstance.profile($0.name) }
        case .profileBindings:
            return Self.desktops(
                present: presentDesktops,
                bound: boundDesktops
            )
            .map(ProfilesRowInstance.desktop)
        case .presetsApply:
            return presets.map {
                ProfilesRowInstance.preset($0.name)
            }
        case .isStarterSetup:
            // Lua-only: a profile identity flag with no Settings
            // surface at all (`SettingPlacement.luaOnly`), so it
            // draws nothing here and never will.
            return nil
        }
    }
}
