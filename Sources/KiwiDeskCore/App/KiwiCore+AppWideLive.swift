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
        // A lens the new values no longer hold turns KiwiVision off.
        if let lens = visionLensName, new.lens(named: lens) == nil {
            setVision(.off)
        }
        let lens = visionLensName
        let before = old.look(lens: lens)
        let after = new.look(lens: lens)
        visionLookChanged(from: before, to: after)
        // The whole stored group, so a field v3 adds re-draws too.
        if new.vision != old.vision, before == after { updateVision() }
        if new.hyperKey != old.hyperKey { oweHyperRemap() }
        onAppWideChange()
    }
}
