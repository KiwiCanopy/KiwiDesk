import KiwiDeskCore

/// The Shared look switch (#1752, #2820): which profiles follow the
/// shared look. The page's switch writes at once through the one
/// `KiwiCore.saveLookReach`; a staged switch, which no page makes
/// now, is written by a Save before that Save's `gui.json` write.
extension SettingsModel {
    /// Whether each profile follows the shared look, as the page
    /// shows it: the stored switches, any staged ones over them.
    var lookFollows: [String: Bool] {
        lookReachStored.merging(lookReachEdits) { $1 }
    }

    /// Stages `profile`'s switch; a switch back to what is stored
    /// drops the edit, so an undone pick leaves nothing unsaved.
    func setLookFollows(_ profile: String, _ follows: Bool) {
        if lookReachStored[profile] == follows {
            lookReachEdits[profile] = nil
        } else {
            lookReachEdits[profile] = follows
        }
    }

    /// The page's switch (#2820), written at once and only over a
    /// clean draft, whose look is then the stored one: `.make` lands
    /// the look the page shows as the shared one. The page reloads,
    /// so it shows what was written. False where it was refused or
    /// the write failed, with a warning.
    @discardableResult
    func applyLookSwitch(_ profile: String, _ pick: LookSwitch) -> Bool {
        guard !isDirty else { return false }
        let sharing =
            pick == .make
            ? (profile: profile, look: LookBody(of: config.settings))
            : nil
        do {
            try core.withUserMotion {
                try core.saveLookReach(
                    [profile: pick != .own],
                    sharing: sharing
                )
            }
        } catch {
            warnLookReachFailed(error)
            return false
        }
        reload()
        return true
    }

    /// The profiles other than `edited` that wear the shared look,
    /// in menu order — the page's "Also used by" line.
    func sharedLookUsers(besides edited: String) -> [String] {
        profileMenuOrder.filter { $0 != edited && lookFollows[$0] == true }
    }

    /// Re-reads the stored switches and drops the staged ones — a
    /// reload, a Revert, a landed Save.
    func resetLookReach() {
        lookReachStored = core.lookReach()
        lookReachEdits = [:]
    }

    /// Writes the staged switches; false where the write failed,
    /// the switches then staying unsaved with a warning.
    @discardableResult
    func saveLookReach() -> Bool {
        guard !lookReachEdits.isEmpty else { return true }
        do {
            try core.saveLookReach(lookReachEdits)
            resetLookReach()
            return true
        } catch {
            warnLookReachFailed(error)
            return false
        }
    }

    private func warnLookReachFailed(_ error: Error) {
        profileWarning = L(
            "profiles.save_failed",
            "Saving failed: %1$@",
            Self.lookReachFailure(error)
        )
        core.onLog("look reach save failed: \(error)")
    }

    /// What a failed look-switch write says after "Saving failed:".
    private static func lookReachFailure(_ error: Error) -> String {
        guard error is LookReachError else {
            return NewerFormatText.detail(error)
        }
        return L(
            "looks.reach.shared_not_written",
            "The shared look couldn't be written."
        )
    }

    /// The save pill's rows for the staged switches, one per profile
    /// whose switch a Save would change — every reason the pill
    /// shows owes a row (gui.md).
    func lookReachDiffRows() -> [SettingsDiffRow] {
        lookReachEdits.keys.sorted().compactMap { profile in
            guard let follows = lookReachEdits[profile] else {
                return nil
            }
            var row = SettingsDiffRow.note(
                .colours(.lookAppliesTo),
                instance: "look.\(profile)",
                label: profile,
                note: follows
                    ? L("looks.reach.diff.uses_shared", "Uses the shared look")
                    : L(
                        "looks.reach.diff.own",
                        "Keeps the look it wears as its own"
                    )
            )
            row.revert = .look(profile: profile)
            return row
        }
    }
}

/// A pick on the page's switch (#2820).
enum LookSwitch {
    case own
    case use
    case make
}
