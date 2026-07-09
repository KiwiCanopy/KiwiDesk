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
        return L(
            "profiles.update_hint",
            "\"%1$@\" is for %2$d screen(s); %3$d connected. "
                + "Save as new instead.",
            name,
            summary.count,
            displays.count
        )
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
        // A save failure must stay visible; only a successful
        // update may show the overlap warning.
        guard persist(named: name) else { return }
        if !overlap.isEmpty {
            let names = overlap.map { "\"\($0)\"" }
                .joined(separator: ", ")
            profileWarning = L(
                "profiles.overlap_warning",
                "This monitor set is also covered by %1$@ "
                    + "— exact-match ties load the "
                    + "alphabetically first.",
                names
            )
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

    @discardableResult
    private func persist(named name: String) -> Bool {
        core.applyProfileScopedState(from: config)
        var saved = true
        do {
            try core.persistProfile(named: name)
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

    // MARK: - Editing a stored profile (#18)

    // `selectEditTarget` lives with the edit-mode state machine
    // in `SettingsModel+EditTarget.swift` (#64);
    // `saveEditedProfile` / `saveEditedProfileCopy` with the
    // rest of the stored-profile editing surface in
    // `SettingsModel+ProfileOverrides.swift`.

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

    /// Renames a saved profile. Immediate, like Delete / make
    /// default (pending edits are discarded by the reload).
    /// The core facade owns the whole chase — file, adopted
    /// name, runtime native-Space bindings, and the sidecar's
    /// binding lines — so the model only retargets its edit
    /// session and reloads.
    /// Collisions are the core's call (the only
    /// case-insensitive tier) — a rejection surfaces as
    /// `profileWarning`, never a silent dead click.
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

    // MARK: - Presets (#53)

    /// Applies a built-in layout and materializes it as a saved
    /// profile named after the preset (`_N` when taken).
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

    // MARK: - Space placement (Canvas)

    /// Where a space renders in the Canvas, via the same
    /// `SpacePlacement` precedence the runtime resolves with
    /// (pin → Main → positional default). There is no
    /// "unassigned" state — defaults compose a concrete
    /// layout (#53). One conscious divergence: a pin to a
    /// disconnected monitor renders as pinned (the user's
    /// intent), while the runtime places the space on the
    /// fallback display until that monitor returns.
    func resolution(for space: SpaceID) -> SpaceResolution {
        let mainID = PositionalDisplays.liveMainID
        let assignment =
            ProfileComposition.compose(
                displays: displays,
                mainID: mainID
            )?.assignment ?? [:]
        let resolved = SpacePlacement.resolve(
            space: space,
            pins: config.spacePins,
            mainSpaces: config.mainSpaces,
            displays: displays,
            mainID: mainID,
            assignment: assignment
        )
        switch resolved {
        case .pinned(let display):
            return .pinned(display.fingerprint)
        case .pinnedAbsent(intent: let pin, fallback: _):
            return .pinned(pin)
        case .main:
            return .main
        case .auto(let display):
            return .auto(display.fingerprint)
        case nil:
            return .auto(nil)
        }
    }

    /// Human-readable monitor name, falling back to the raw
    /// fingerprint when that display isn't connected — used by
    /// the Monitors cards and the profile rows (§3.15).
    func monitorName(_ fingerprint: String) -> String {
        displays.first {
            $0.fingerprint == fingerprint
        }?.name ?? fingerprint
    }

    /// The current main display's fingerprint, for the Main
    /// drop target's live annotation. Falls back positionally
    /// (leftmost), matching the runtime.
    var mainFingerprint: String? {
        let mainID = PositionalDisplays.liveMainID
        return
            (displays.first { $0.id == mainID }
            ?? PositionalDisplays.ordered(
                displays,
                mainID: mainID
            ).first)?.fingerprint
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
