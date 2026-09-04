import CoreGraphics
import KiwiDeskCore

/// One row of the Desktop bindings card: which Desktop it acts
/// on, the Mission Control number it is LABELLED with, and
/// whether that Desktop is in any current reading (#1147).
struct DesktopRow: Hashable {
    let key: DesktopKey
    let number: Int
    /// No reading names this Desktop — its screen is unplugged,
    /// or it was deleted. The record is kept either way.
    let isDormant: Bool
}

/// Instance representing expanded row in Profiles census (#678).
enum ProfilesRowInstance: Hashable {
    case profile(String)
    /// By the DESKTOP, never its Mission Control number (#1147):
    /// a dormant record and a live Desktop can carry the same
    /// number, and identifying a row by it makes the dormant one
    /// unreachable — the exact post-renumber case this lane is
    /// about (architect review, 2026-09-04).
    case desktop(DesktopKey)
    /// By the stable English `StandardLayout.name` — identity must
    /// not move with the GUI language.
    case preset(String)
}

/// Expands Profiles census keys into rendered instances (#678,
/// `ProfilesCensusRenderTests`).
struct ProfilesFamilyRows {
    let profiles: [ProfileSummary]
    /// Main display Mission Control desktops (#888).
    let mainDesktops: [Int]
    /// Each present Desktop's key by its Mission Control number.
    let desktopKeys: [Int: DesktopKey]
    /// Every key the topology answers to (`DesktopSnapshot`).
    let presentKeys: Set<DesktopKey>
    /// The bindings as the draft currently holds them.
    let bindings: [DesktopKey: DesktopBinding]
    let presets: [StandardLayout]

    func rows(for key: SettingKey) -> [ProfilesRowInstance]? {
        guard case .profiles(let family) = key else { return nil }
        return rows(for: family)
    }

    /// Sorts profiles by live display match, screen count match, count, and
    /// name
    /// (`ProfilesFamilyRowsTests`, `ProfilesGateWiringTests`).
    static func orderedProfiles(
        _ summaries: [ProfileSummary]
    ) -> [ProfileSummary] {
        func key(
            _ summary: ProfileSummary
        ) -> (Int, Int, Int, String) {
            (
                summary.matchesLive ? 0 : 1,
                summary.matchesConnectedCount ? 0 : 1,
                summary.count,
                summary.name
            )
        }
        return summaries.sorted { key($0) < key($1) }
    }

    /// The card's rows: every Desktop on the main screen, every
    /// bound Desktop wherever it lives, and every binding whose
    /// Desktop no reading can name (#888, #1147).
    ///
    /// Takes the NUMBERS for the live half, never a count —
    /// main's Desktops can be 3 and 4, and `1...n` would renumber
    /// them (owner QA, 2026-08-18). A DORMANT record gets a row
    /// of its own even where a live Desktop already holds the
    /// number it was last seen at, because otherwise the two
    /// collapse and the record is unreachable.
    static func desktops(
        onMain: some Collection<Int>,
        keys: [Int: DesktopKey],
        present: Set<DesktopKey>,
        bindings: [DesktopKey: DesktopBinding]
    ) -> [DesktopRow] {
        // A Desktop is BOUND under either of its keys — its
        // stamp, or the number it was filed at before Core
        // re-keyed it — which coexist for one reading.
        let live = Set(onMain).union(
            keys.filter { number, key in
                bindings[key] != nil
                    || bindings[.number(number)] != nil
            }
            .keys
        )
        var rows = live.compactMap { number in
            keys[number].map {
                DesktopRow(key: $0, number: number, isDormant: false)
            }
        }
        // DORMANT is Core's own verdict, handed in — never a
        // second copy switching on `DesktopKey`'s cases here. The
        // copy diverged once already this round, and #1230 moves
        // Core's rule without touching a copy in a row builder
        // (architect review, 2026-09-04).
        rows += bindings.filter { !present.contains($0.key) }
            .map {
                DesktopRow(
                    key: $0.key,
                    number: $0.value.desktop,
                    isDormant: true
                )
            }
        return rows.sorted {
            ($0.number, $0.isDormant ? 1 : 0)
                < ($1.number, $1.isDormant ? 1 : 0)
        }
    }

    /// Presets matching screen count, including starter derivation (#678).
    static func presets(
        forScreens screens: Int,
        sizes: [CGSize]
    ) -> [StandardLayout] {
        StandardProfiles.layouts(for: screens, sizes: sizes)
    }

    /// Presets excluding current connected screen count.
    static func presets(
        excludingScreens screens: Int
    ) -> [StandardLayout] {
        StandardProfiles.workflows.filter {
            $0.screenCount != screens
        }
    }

    /// Expands census family key into row instances, reaching the
    /// same statics the views call — one derivation, the join
    /// proved: mutating it reds `ProfilesFamilyRowsTests` AND
    /// `ProfilesCensusRenderTests.instanceCounts` together.
    private func rows(
        for family: ProfilesKey
    ) -> [ProfilesRowInstance]? {
        switch family {
        case .profilesLoad, .profilesDelete, .profilesRename,
            .isDefault:
            return Self.orderedProfiles(profiles)
                .map { ProfilesRowInstance.profile($0.name) }
        case .profileBindings:
            return Self.desktops(
                onMain: mainDesktops,
                keys: desktopKeys,
                present: presentKeys,
                bindings: bindings
            )
            .map { ProfilesRowInstance.desktop($0.key) }
        case .presetsApply, .presetsLayouts:
            return presets.map {
                ProfilesRowInstance.preset($0.name)
            }
        case .isStarterSetup:
            return nil
        }
    }
}
