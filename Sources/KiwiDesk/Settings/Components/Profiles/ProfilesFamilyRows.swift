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
    /// The screen this Desktop lives on, by name (#1438): the
    /// topology's for a live row, the record's remembered one
    /// for a dormant row; nil where neither has named it.
    let screen: String?
    /// The record this Desktop's binding sits in, under either
    /// of its keys (#1436) — resolved ONCE here, so the card and
    /// the census read one answer.
    let binding: DesktopBinding?
}

/// Which binding a Desktops-card row edits (#1436): the profile
/// for one screen count, or one bound name no saved profile
/// carries a count for.
enum BindingSlot: Hashable {
    case count(Int)
    case orphan(String)
}

/// One group of the Desktops card (#1436, ui-designer ruling):
/// every Desktop row once per screen count a saved profile
/// exists for, the connected count first, and a last group of
/// the bound names whose profile file no reading can count.
enum BindingGroup: Hashable {
    /// `leads`: this count is the connected one, so its
    /// bindings are the ones that fire.
    case count(Int, leads: Bool, rows: [DesktopRow])
    case orphans([OrphanBinding])
}

/// The screen counts the Desktops card groups by (#1436): the
/// connected count where a saved profile exists for it, then
/// every other count a saved profile exists for, ascending.
struct BindingCounts: Hashable {
    let leading: Int?
    let others: [Int]
    /// Nothing leads because there is no display reading yet —
    /// Core's `.displaysUnknown` — rather than because no
    /// profile is saved for the connected count.
    let displaysUnknown: Bool
    var all: [Int] { (leading.map { [$0] } ?? []) + others }
}

/// A bound name whose profile is gone or unreadable, on the
/// Desktop it is bound to.
struct OrphanBinding: Hashable {
    let row: DesktopRow
    let profile: String
}

/// Instance representing expanded row in Profiles census (#678).
enum ProfilesRowInstance: Hashable {
    case profile(String)
    /// By the DESKTOP, never its Mission Control number (#1147):
    /// a dormant record and a live Desktop can carry the same
    /// number, and identifying a row by it makes the dormant one
    /// unreachable — the exact post-renumber case this lane is
    /// about (architect review, 2026-09-04). And by the SLOT
    /// (#1436): one Desktop draws a picker per count group.
    case binding(DesktopKey, BindingSlot)
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
    /// Each present Desktop's screen name by key (#1438).
    let desktopScreens: [DesktopKey: String]
    /// The bindings as the draft currently holds them.
    let bindings: [DesktopKey: DesktopBinding]
    /// Screens connected right now — which count group leads.
    let connectedScreens: Int
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
    ///
    /// `screens` is the topology's screen per present key
    /// (`KiwiCore.desktopScreens`): a live row is named by it, a
    /// dormant row by what its record remembers (#1438).
    static func desktops(
        onMain: some Collection<Int>,
        keys: [Int: DesktopKey],
        present: Set<DesktopKey>,
        screens: [DesktopKey: String],
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
            keys[number].map { key in
                let record =
                    bindings[key] ?? bindings[.number(number)]
                return DesktopRow(
                    key: key,
                    number: number,
                    isDormant: false,
                    screen: screens[key] ?? record?.screen,
                    binding: record
                )
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
                    isDormant: true,
                    screen: $0.value.screen,
                    binding: $0.value
                )
            }
        return rows.sorted {
            ($0.number, $0.isDormant ? 1 : 0)
                < ($1.number, $1.isDormant ? 1 : 0)
        }
    }

    /// Which count leads is Core's fit judgement, so an unknown
    /// display reading leads with nothing — the ONE derivation
    /// the card's caption and headers read.
    static func bindingCounts(
        profiles: [ProfileSummary],
        connected: Int
    ) -> BindingCounts {
        let counts = Set(profiles.map(\.count)).sorted()
        var leading: Int?
        var unknown = false
        for count in counts where leading == nil {
            switch DesktopBindingRefusal.of(
                profileCount: count,
                connected: connected
            ) {
            case nil: leading = count
            case .displaysUnknown?: unknown = true
            case .screenCount?, .unreadable?: break
            }
        }
        return BindingCounts(
            leading: leading,
            others: counts.filter { $0 != leading },
            displaysUnknown: unknown
        )
    }

    /// Each readable saved profile's screen count by name — the
    /// one map the groups and the card's pickers read.
    static func profileCounts(
        _ profiles: [ProfileSummary]
    ) -> [String: Int] {
        Dictionary(
            profiles.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The card's groups over its Desktop rows: `rows` once per
    /// count, then the orphans — each bound name whose profile
    /// `profileCounts` cannot count, on the row it is bound to.
    static func bindingGroups(
        rows: [DesktopRow],
        counts: BindingCounts,
        profileCounts: [String: Int]
    ) -> [BindingGroup] {
        var groups = counts.all.map {
            BindingGroup.count($0, leads: $0 == counts.leading, rows: rows)
        }
        let orphans = rows.flatMap { row in
            (row.binding?.profiles ?? [])
                .filter { profileCounts[$0] == nil }
                .map { OrphanBinding(row: row, profile: $0) }
        }
        if !orphans.isEmpty { groups.append(.orphans(orphans)) }
        return groups
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
            .isDefault, .profilesAddScreenSetup:
            return Self.orderedProfiles(profiles)
                .map { ProfilesRowInstance.profile($0.name) }
        case .profileBindings:
            let rows = Self.desktops(
                onMain: mainDesktops,
                keys: desktopKeys,
                present: presentKeys,
                screens: desktopScreens,
                bindings: bindings
            )
            return Self.bindingGroups(
                rows: rows,
                counts: Self.bindingCounts(
                    profiles: profiles,
                    connected: connectedScreens
                ),
                profileCounts: Self.profileCounts(profiles)
            )
            .flatMap { group -> [ProfilesRowInstance] in
                switch group {
                case .count(let count, _, let rows):
                    return rows.map { .binding($0.key, .count(count)) }
                case .orphans(let orphans):
                    return orphans.map {
                        .binding($0.row.key, .orphan($0.profile))
                    }
                }
            }
        case .presetsApply, .presetsLayouts:
            return presets.map {
                ProfilesRowInstance.preset($0.name)
            }
        case .isStarterSetup:
            return nil
        }
    }
}
