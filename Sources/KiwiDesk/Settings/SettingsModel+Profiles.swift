import Foundation
import KiwiDeskCore
import SwiftUI

/// Profile save, load, and preset operations for dashboard model (#36, #53).
extension SettingsModel {
    /// Explains why profile saving is blocked when accessibility is disabled
    /// (#335, #516).
    var profileSaveBlockedReason: String? {
        guard permissionPaused else { return nil }
        return L(
            "profiles.save_blocked_paused",
            "Window management is paused because Accessibility "
                + "access is off, so no displays are detected. "
                + "Grant access first — a profile saved now would "
                + "capture no monitors and never resolve."
        )
    }

    /// Whether active profile matches connected screen count for update.
    var updateEnabled: Bool {
        guard let name = activeProfile,
            let summary = profileSummaries.first(where: {
                $0.name == name
            })
        else { return false }
        return summary.count == displays.count
    }

    /// Tooltip explanation when active profile screen count differs from
    /// connected displays.
    var updateHint: String? {
        guard let name = activeProfile,
            let summary = profileSummaries.first(where: {
                $0.name == name
            }), summary.count != displays.count
        else { return nil }
        return L(
            "profiles.update_hint",
            "\"%1$@\" is for %2$d screen(s); %3$d connected. "
                + "Save as new instead.",
            name,
            summary.count,
            displays.count
        )
    }

    /// Persists edited tiling into active profile and refreshes monitor set.
    func updateActiveProfile() {
        guard let name = activeProfile else { return }
        let overlap = core.profilesClaimingLiveSet(
            excluding: name
        )
        guard persist(named: name) else { return }
        if !overlap.isEmpty {
            let names = overlap.map { "\"\($0)\"" }
                .joined(separator: ", ")
            profileWarning = L(
                "profiles.overlap_warning",
                "This screen setup is also used by %1$@ "
                    + "— if multiple profiles match on startup, "
                    + "the first one alphabetically is loaded.",
                names
            )
        }
    }

    /// Creates new profile with unique name capturing live monitor set.
    func saveAsNewProfile(named name: String) {
        let trimmed = name.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        persist(named: core.profiles.freeName(base: trimmed))
    }

    /// A Settings Save is a DRAFT COMMIT, and the two lines
    /// below are what that means (#1179).
    ///
    /// It applies only the modes the draft actually edited, and
    /// it writes the DRAFT's modes to the file — never live's. A
    /// whole-profile re-apply here is Revert semantics wearing a
    /// Save label: it destroys a standing quick-menu layout the
    /// save pill never counted, which is the bug this closes,
    /// and capturing live instead would silently adopt that same
    /// temporary layout into the file, which is its mirror. The
    /// quick menu's Keep verb is the capture-live path and stays
    /// separate.
    ///
    /// "Edited" is `SettingsDraftDiff`'s answer, the same seam
    /// the pill count and the unsaved popover read — never a
    /// comparison re-derived beside this apply.
    @discardableResult
    private func persist(named name: String) -> Bool {
        core.mergeLiveSpaces(
            into: &config,
            seededWith: seedSpaces
        )
        let edited = SettingsDraftDiff.between(
            config: config,
            cleanConfig: cleanConfig,
            luaSource: luaSource,
            cleanLuaSource: cleanLuaSource
        ).editedSpaceModes
        core.applyProfileScopedState(
            from: config,
            applyingModesFor: edited
        )
        var saved = true
        do {
            try core.persistProfile(
                named: name,
                modes: config.modes(
                    for: core.state.workspaces.allSpaces.map(\.id)
                )
            )
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("profile save failed: \(error)")
            saved = false
        }
        persistGlobalsIfNeeded()
        reload()
        return saved
    }

    /// Persists global configuration when non-profile settings changed (#36).
    private func persistGlobalsIfNeeded() {
        guard globalsChanged else { return }
        do {
            try core.saveGuiConfig(config)
        } catch {
            core.onLog("settings save failed: \(error)")
        }
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

    /// Renames profile file, references, and active edit target.
    func renameProfile(from old: String, to new: String) {
        let name = new.trimmed
        guard name != old, !name.isEmpty else { return }
        do {
            try core.renameProfile(from: old, to: name)
        } catch {
            profileWarning = L(
                "profiles.rename_failed",
                "Renaming failed: %1$@",
                "\(error)"
            )
            return
        }
        if target == .storedProfile(old) {
            target = .storedProfile(name)
        }
        reload()
    }

    /// Applies standard layout preset as saved profile (#53).
    func applyStandardPreset(_ layout: StandardLayout) {
        do {
            try core.applyStandard(layout)
        } catch {
            profileWarning = L(
                "profiles.apply_failed",
                "Applying failed: %1$@",
                "\(error)"
            )
            core.onLog("preset apply failed: \(error)")
        }
        reload()
    }
}

/// Saved profile summary for profile list and resolution (#36, #789, #678).
struct ProfileSummary: Identifiable {
    let name: String
    let count: Int
    let sets: [[String]]
    let isDefault: Bool
    let matchesLive: Bool
    let matchesConnectedCount: Bool
    let openingModes: [LayoutMode?]
    let spaceCount: Int
    let shortcutOverrideCount: Int
    var id: String { name }
}

/// Unparseable profile with failure cause (#246).
struct BrokenProfile: Identifiable, Equatable {
    let name: String
    let cause: ProfileBrokenCause
    var id: String { name }
}

/// Resolution verdict and screen count for profile loading card (#678).
struct ProfileResolution: Equatable {
    let verdict: ProfileVerdict
    let screens: Int
}
