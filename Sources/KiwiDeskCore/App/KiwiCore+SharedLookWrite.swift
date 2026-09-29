import Foundation

/// The writes that change the shared look (#1752), each landing
/// through the one `landSharedLook`: `gui.json` first, then every
/// following profile's file copy re-stamped and the live screen
/// re-resolved, so no copy and no screen goes stale.
extension KiwiCore {
    /// The live profile's switch, which a Keep or Save as of it
    /// copies (#1752 ruling): nil for a built-in, which follows.
    var liveLookReference: LookReference? {
        profiles.currentName.flatMap { try? profiles.read(name: $0) }?
            .look
    }

    /// The switch a NEW profile is born with, copied from its
    /// source's: own while no shared look exists, since following
    /// then would make it wear, at the crossing, a look it never
    /// did (`SharedLookWriteTests`).
    func lookReference(forNew source: LookReference?) -> LookReference? {
        sharedLook == nil ? .own : source
    }

    /// The one door a write of a FOLLOWER's settings takes: its
    /// look is the shared one, so that is where the write lands —
    /// otherwise the next apply would paint the old shared look
    /// over it. A Keep, a Save as, a stored-profile Settings Save
    /// (`commitSharedLook`) and the tour's paint reach it; an own
    /// profile's write is its own, and before the crossing there is
    /// no shared look to write — the crossing alone seeds it
    /// (`SharedLookWriteTests`).
    func recordLookWrite(of profile: Profile) {
        guard profile.look == nil, sharedLook != nil, isGuiManaged
        else { return }
        let written = LookBody(of: profile.settings)
        guard written != sharedLook else { return }
        landSharedLook(written)
    }

    /// A stored-profile Settings Save's look half (#1752): the
    /// edited profile follows, so the draft's look is the shared
    /// one. Its own step, beside `overwriteProfile`, which writes
    /// the profile file alone.
    public func commitSharedLook(ofProfile name: String) {
        guard let saved = try? profiles.read(name: name) else { return }
        recordLookWrite(of: saved)
    }

    /// Lands `base` as the shared look: `gui.json` first, and only
    /// once that write landed is every follower's file copy
    /// re-stamped — the snapshot an older build or a Lua-owned load
    /// reads, never read while it follows — and the live screen
    /// re-resolved. A failed write changes nothing.
    @discardableResult
    func landSharedLook(_ base: LookBody) -> Bool {
        let before = sharedLookLedger
        sharedLookLedger.base = base
        sharedLookLedger.owed = false
        guard persistSharedLook() else {
            sharedLookLedger = before
            return false
        }
        restampFollowers()
        reresolveLiveLook()
        return true
    }

    /// Every follower's file copy made to wear the shared look.
    /// Non-adopting, and a copy already wearing it is not rewritten.
    private func restampFollowers() {
        guard let base = sharedLook else { return }
        for name in profiles.list() {
            guard var stored = try? profiles.read(name: name),
                stored.look == nil, !base.isWorn(by: stored.settings)
            else { continue }
            stored.settings = wearingSharedLook(stored.settings)
            do {
                try profiles.write(stored)
            } catch {
                onLog("shared look: \(name) not re-stamped: \(error)")
            }
        }
    }

    /// The live screen's look re-read where it follows — a
    /// following profile or a built-in — through the look alone,
    /// never a whole-profile re-apply, which would reach a standing
    /// temporary layout (#1179).
    func reresolveLiveLook() {
        guard liveLookReference == nil else { return }
        let worn = wearingSharedLook(tiler.settings)
        guard worn != tiler.settings else { return }
        tiler.settings = worn
        retile(pass: .apply)
    }

    /// Writes `gui.json` with the stamp; false where nothing
    /// landed.
    @discardableResult
    func persistSharedLook() -> Bool {
        guard let config = guiConfigStore.load() else {
            onLog("shared look: gui.json unreadable, not saved")
            return false
        }
        do {
            try guiConfigStore.save(config)
            return true
        } catch {
            onLog("shared look: gui.json write failed: \(error)")
            return false
        }
    }
}
