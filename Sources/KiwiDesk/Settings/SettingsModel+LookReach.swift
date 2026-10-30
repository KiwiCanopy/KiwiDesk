import KiwiDeskCore

/// The Shared look switch's draft half (#1752, #2820): its picks
/// are staged like any edit and written by a Save through the one
/// `KiwiCore.saveLookReach`, before that Save's `gui.json` write.
extension SettingsModel {
    /// Whether each profile follows the shared look, as the page
    /// shows it: the stored switches, the draft's picks over them.
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

    /// The page's switch (#2820), the one writer of what it
    /// stages: the follow, the share and the draft's paint move
    /// together. `.use` paints the shared look over the draft only
    /// for a profile stored with its own, so the page shows what the
    /// Save keeps; switching back from it takes the paint off.
    func stageLookSwitch(_ profile: String, _ pick: LookSwitch) {
        restorePaintedLook()
        let stored = lookReachStored[profile]
        switch pick {
        case .own:
            setLookFollows(profile, false)
        case .make:
            lookShare = .make(profile: profile)
            setLookFollows(profile, true)
        case .use:
            if stored == false, let shared = core.sharedLook {
                lookShare = .use(profile: profile, paintBase: config.settings)
                config.settings = shared.worn(over: config.settings)
            }
            setLookFollows(profile, true)
        }
    }

    /// The switch back to what is stored, its paint taken off — the
    /// pill row's ↺.
    func revertLookSwitch(_ profile: String) {
        restorePaintedLook()
        lookShare = nil
        if let stored = lookReachStored[profile] {
            setLookFollows(profile, stored)
        } else {
            lookReachEdits[profile] = nil
        }
    }

    /// Takes a staged "Use the shared look" off the draft: its paint
    /// and the share, never the follow.
    private func restorePaintedLook() {
        if case .use(_, let base) = lookShare {
            config.settings = ShelfLook.unpicked(config.settings, to: base)
        }
        lookShare = nil
    }

    /// The profiles other than `edited` that wear the shared look,
    /// in menu order — the page's "Also used by" line.
    func sharedLookUsers(besides edited: String) -> [String] {
        profileMenuOrder.filter { $0 != edited && lookFollows[$0] == true }
    }

    /// Re-reads the stored switches and drops the picks — a reload,
    /// a Revert, a landed Save.
    func resetLookReach() {
        lookReachStored = core.lookReach()
        lookShare = nil
        lookReachEdits = [:]
    }

    /// Writes the staged switches; false where the write failed,
    /// the picks then staying unsaved with a warning.
    @discardableResult
    func saveLookReach() -> Bool {
        guard !lookReachEdits.isEmpty else { return true }
        repaintSharedLook()
        do {
            try core.saveLookReach(lookReachEdits, sharing: sharing)
            resetLookReach()
            return true
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                Self.lookReachFailure(error)
            )
            core.onLog("look reach save failed: \(error)")
            return false
        }
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

    /// A staged "Use the shared look" painted again on the leaves
    /// taken back to the own look since — a setting's ↺, Simple's
    /// look row — from the shared look as it is at the Save, so no
    /// own value lands as an edit of the shared look (#2820). A leaf
    /// the user changed since is an edit of the shared look, and
    /// stays.
    private func repaintSharedLook() {
        guard case .use(_, let base) = lookShare,
            let shared = core.sharedLook
        else { return }
        let worn = shared.worn(over: config.settings)
        let now = LookBody(of: config.settings)
        let was = LookBody(of: base)
        let want = LookBody(of: worn)
        let style = want.style.filter {
            now.style[$0.key] == was.style[$0.key]
                && now.style[$0.key] != $0.value
        }
        let colors = want.colors.filter {
            now.colors[$0.key] == was.colors[$0.key]
                && now.colors[$0.key] != $0.value
        }
        // A pick, not a wear: keep the per-layout indicators the
        // apply clears, as `LookBody.worn` keeps them (#2368).
        let before = config.settings
        ShelfLook(name: "", style: style, colors: colors)
            .apply(to: &config.settings)
        for leaf in TilingSettings.layoutIndicatorLeaves {
            config.settings[keyPath: leaf] = before[keyPath: leaf]
        }
        if now.origin == was.origin {
            config.settings.lookOrigin = worn.lookOrigin
        }
    }

    /// The profile staged to make its look the shared one, with the
    /// look the page shows it wearing — over live as it is now on
    /// the loaded profile's Save, as that Save rebases (#2262).
    private var sharing: (profile: String, look: LookBody)? {
        guard case .make(let profile) = lookShare else { return nil }
        let shown =
            editingProfile == nil
            ? config.settings.rebased(
                from: cleanConfig.settings,
                onto: core.tiler.settings
            )
            : config.settings
        return (profile, LookBody(of: shown))
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
                note: lookReachNote(profile, follows: follows)
            )
            row.revert = .look(profile: profile)
            return row
        }
    }

    private func lookReachNote(_ profile: String, follows: Bool) -> String {
        guard follows else {
            return L(
                "looks.reach.diff.own",
                "Keeps the look it wears as its own"
            )
        }
        return lookShare?.makes(profile) == true
            ? L(
                "looks.reach.diff.becomes_shared",
                "Its look becomes the shared look"
            )
            : L("looks.reach.diff.uses_shared", "Uses the shared look")
    }
}

/// A pick on the page's switch (#2820).
enum LookSwitch {
    case own
    case use
    case make
}

/// What the switch staged beyond the follow (#2820): one profile's
/// share at a time, since a page stages only its own.
enum LookShareStage {
    /// "Use the shared look", with the draft from before the shared
    /// look was painted over it.
    case use(profile: String, paintBase: TilingSettings)
    /// "Make this the shared look": the draft's look lands as the
    /// shared one at the Save.
    case make(profile: String)

    func makes(_ name: String) -> Bool {
        if case .make(let profile) = self { return profile == name }
        return false
    }
}
