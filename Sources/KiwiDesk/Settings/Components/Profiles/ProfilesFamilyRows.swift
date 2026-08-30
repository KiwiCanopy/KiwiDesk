import CoreGraphics
import KiwiDeskCore

/// Instance representing expanded row in Profiles census (#678).
enum ProfilesRowInstance: Hashable {
    case profile(String)
    case desktop(Int)
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
    /// Desktops currently bound by settings.
    let boundDesktops: [Int]
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

    /// Union of main screen desktops and already-bound desktops
    /// (#888). Takes the NUMBERS, never a count — main's Desktops
    /// can be 3 and 4, and `1...n` would renumber them (owner QA,
    /// 2026-08-18).
    static func desktops(
        onMain: some Collection<Int>,
        bound: some Collection<Int>
    ) -> [Int] {
        Array(Set(onMain).union(bound)).sorted()
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
                bound: boundDesktops
            )
            .map(ProfilesRowInstance.desktop)
        case .presetsApply, .presetsLayouts:
            return presets.map {
                ProfilesRowInstance.preset($0.name)
            }
        case .isStarterSetup:
            return nil
        }
    }
}
