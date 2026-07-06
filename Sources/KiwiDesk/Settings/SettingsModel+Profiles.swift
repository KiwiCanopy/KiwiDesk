import Foundation
import KiwiDeskCore
import SwiftUI

/// The profile half of the dashboard model (#36/#53): the
/// two-button save UX (Update / Save as new), the preset Apply
/// flow, list actions, and the Canvas placement resolution.
extension SettingsModel {
    /// Whether Update can write into the active profile: it
    /// exists and covers the live screen count. A different
    /// count (extra screen attached) needs "Save as new…".
    var updateEnabled: Bool {
        guard let name = activeProfile,
            let summary = profileSummaries.first(where: {
                $0.name == name
            })
        else { return false }
        return summary.count == displays.count
    }

    /// The greyed-out Update button's explanation, when any.
    var updateHint: String? {
        guard let name = activeProfile,
            let summary = profileSummaries.first(where: {
                $0.name == name
            }), summary.count != displays.count
        else { return nil }
        return "\"\(name)\" is for \(summary.count) screen(s); "
            + "\(displays.count) connected. Save as new instead."
    }

    /// Update "<profile>": persists the edited tiling into the
    /// active profile and adds/refreshes the live monitor set.
    /// Warns (without mutating them) when other profiles also
    /// claim this monitor set.
    func updateActiveProfile() {
        guard let name = activeProfile else { return }
        let overlap = core.profilesClaimingLiveSet(
            excluding: name
        )
        persist(named: name)
        if !overlap.isEmpty {
            profileWarning =
                "This monitor set is also covered by "
                + overlap.map { "\"\($0)\"" }
                .joined(separator: ", ")
                + " — exact-match ties load the "
                + "alphabetically first."
        }
    }

    /// Save as new…: creates a profile carrying only the live
    /// monitor set (name auto-suffixed `_1`, `_2`, … if taken).
    func saveAsNewProfile(named name: String) {
        let trimmed = name.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        persist(named: core.profiles.freeName(base: trimmed))
    }

    private func persist(named name: String) {
        core.applyProfileScopedState(from: config)
        do {
            try core.persistProfile(named: name)
        } catch {
            profileWarning = "Saving failed: \(error)"
            core.onLog("profile save failed: \(error)")
        }
        persistGlobalsIfNeeded()
        reload()
    }

    /// The sidecar and `init.lua` only regenerate when a global
    /// (non-profile) setting actually changed, keeping their
    /// diffs clean (#36).
    private func persistGlobalsIfNeeded() {
        guard globalsChanged else { return }
        do {
            try core.saveGuiConfig(config)
        } catch {
            core.onLog("settings save failed: \(error)")
        }
    }

    private var globalsChanged: Bool {
        guard let saved = savedSidecar else { return true }
        return saved.modes != config.modes
            || saved.appRules != config.appRules
            || saved.floatRules != config.floatRules
            || saved.profileBindings != config.profileBindings
            || saved.spaces != config.spaces
    }

    func loadProfile(named name: String) {
        _ = core.execute(
            "load_profile",
            args: [.string(name)]
        )
        reload()
    }

    func deleteProfile(named name: String) {
        _ = core.execute(
            "delete_profile",
            args: [.string(name)]
        )
        reload()
    }

    func makeDefault(named name: String) {
        _ = core.execute(
            "set_default_profile",
            args: [.string(name)]
        )
        refreshProfiles()
    }

    // MARK: - Presets (#53)

    /// Applies a built-in layout and materializes it as a saved
    /// profile named after the preset (`_N` when taken).
    func applyStandardPreset(_ layout: StandardLayout) {
        do {
            try core.applyStandard(layout)
        } catch {
            profileWarning = "Applying failed: \(error)"
            core.onLog("preset apply failed: \(error)")
        }
        reload()
    }

    // MARK: - Space placement (Canvas)

    /// Where a space renders in the Canvas, mirroring the
    /// runtime precedence: pin → Main → positional default.
    /// There is no "unassigned" state — defaults compose a
    /// concrete layout (#53).
    func resolution(for space: SpaceID) -> SpaceResolution {
        if let pin = config.spacePins[space] {
            return .pinned(pin)
        }
        if config.mainSpaces.contains(space) {
            return .main
        }
        let mainID = PositionalDisplays.liveMainID
        if let composed = ProfileComposition.compose(
            displays: displays,
            mainID: mainID
        ), let assigned = composed.assignment[space],
            let display = displays.first(where: {
                $0.id == assigned
            })
        {
            return .auto(display.fingerprint)
        }
        let main =
            displays.first { $0.id == mainID }
            ?? displays.first
        return .auto(main?.fingerprint)
    }

    /// The current main display's fingerprint, for the Main
    /// drop target's live annotation.
    var mainFingerprint: String? {
        let mainID = PositionalDisplays.liveMainID
        return
            (displays.first { $0.id == mainID }
            ?? displays.first)?.fingerprint
    }
}

/// One saved profile as the load list shows it (#36).
struct ProfileSummary: Identifiable {
    let name: String
    let count: Int
    /// Each covered monitor combination, as fingerprints.
    let sets: [[String]]
    let isDefault: Bool
    /// One of the sets equals the live monitors.
    let matchesLive: Bool
    var id: String { name }
}

/// How a space's screen resolves in the Canvas (#36).
enum SpaceResolution: Equatable {
    case pinned(String)
    case main
    /// Auto-assigned by the positional default (#53).
    case auto(String?)
}
