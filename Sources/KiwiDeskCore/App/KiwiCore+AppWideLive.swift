import Foundation

/// The one apply seam for app-wide values (#1741): every change of
/// `appWideLedger.live` lands here through its `didSet`.
extension KiwiCore {
    /// Every change of the live app-wide values — a verb, a row,
    /// a `gui.json` reload, restore or reset — reaches the plate,
    /// the appearance ledger and the Hyper remap here
    /// (`appWideLedger`'s `didSet`), so none of them leaves a
    /// consumer out of step.
    func appWideLiveChanged(from old: AppWideSettings) {
        let new = appWide
        guard new != old else { return }
        let handled = followActiveLens(
            from: old,
            renaming: vision.renamedLens
        )
        let lens = visionLensName
        let before = old.look(lens: lens)
        let after = new.look(lens: lens)
        if !handled { visionLookChanged(from: before, to: after) }
        // The whole stored group, so a field v3 adds re-draws too.
        if new.vision != old.vision, before == after { updateVision() }
        if new.hyperKey != old.hyperKey { oweHyperRemap() }
        if new.modifierSides != old.modifierSides {
            keys.modifierSides = new.modifierSides
        }
        onAppWideChange()
    }

    /// The lens on, judged again after a write of the lenses or a
    /// change of the live profile: one the values no longer hold,
    /// or that Core refuses, turns KiwiVision off — with ruling
    /// 16's cue where the profile left it out — and one stored
    /// under another spelling, or renamed by the write itself
    /// (`renaming`), is followed to it. `old` is the values before
    /// a write.
    /// True where it moved the active value, whose own door then
    /// took the change of look.
    @discardableResult
    func followActiveLens(
        from old: AppWideSettings? = nil,
        renaming: (from: String, to: String)? = nil
    ) -> Bool {
        guard let name = visionLensName else { return false }
        let before = (old ?? appWide).look(lens: name)
        let follow =
            renaming.flatMap {
                AppWideSettings.sameLens($0.from, name) ? $0.to : nil
            } ?? name
        guard let lens = appWide.lens(named: follow) else {
            setVision(.off, from: before)
            return true
        }
        if let refusal = lensRefusal(lens) {
            // An emptied lens goes off silently: the define that
            // emptied it was the user's own act.
            var cause: VisionChangeCause?
            if case .outOfReach(let profile) = refusal {
                cause = .outOfReach(lens: lens.name, profile: profile)
            }
            setVision(.off, from: before, cause: cause)
            return true
        }
        guard lens.name != name else { return false }
        setVision(.lens(lens.name), from: before)
        return true
    }
}
