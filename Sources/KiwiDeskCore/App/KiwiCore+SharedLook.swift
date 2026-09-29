import Foundation

/// The shared look's state (#1752).
struct SharedLookLedger {
    /// The look `gui.json` carries; nil before one is adopted.
    var base: LookBody?
    /// Whether the crossing is owed: a readable, GUI-managed
    /// `gui.json` that carries no look yet.
    var owed = false
}

/// The look every profile without its own wears (#1752) — the one
/// home of every write to `sharedLookLedger`, and of the one
/// reading of which settings a profile runs with.
extension KiwiCore {
    /// The shared look, or nil before one is adopted or while the
    /// config is Lua-owned, which has no shared look — the load
    /// that finds it Lua-owned clears the ledger
    /// (`prepareSharedLook`), so this never asks `isGuiManaged`,
    /// whose store read stamps this very value.
    public var sharedLook: LookBody? { sharedLookLedger.base }

    /// What every `gui.json` write stamps in
    /// (`GuiConfigStore.liveLook`).
    var sharedLookStamp: LookBody? { sharedLook }

    /// The settings `profile` runs with: its own, or — while it
    /// follows the shared look — its own with that look painted
    /// over (`ShelfLook.admitted`). The one reading of a stored
    /// profile's look; a Lua-owned config reads the profile alone.
    public func resolvedSettings(of profile: Profile) -> TilingSettings {
        profile.look == .own
            ? profile.settings : wearingSharedLook(profile.settings)
    }

    /// `settings` with the shared look painted over — what a
    /// follower and a built-in layout wear, a built-in having no
    /// file to be own in (#1752).
    func wearingSharedLook(_ settings: TilingSettings) -> TilingSettings {
        guard let base = sharedLook else { return settings }
        var worn = settings
        base.named("").admitted.apply(to: &worn)
        return worn
    }

    /// The live profile's switch, which a Keep or Save as of it
    /// copies (#1752 ruling): nil for a built-in, which follows.
    var liveLookReference: LookReference? {
        profiles.currentName.flatMap { try? profiles.read(name: $0) }?
            .look
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
        guard profile.look == nil, sharedLookLedger.base != nil,
            isGuiManaged
        else { return }
        let written = LookBody(of: profile.settings)
        guard written != sharedLookLedger.base else { return }
        let before = sharedLookLedger
        sharedLookLedger.base = written
        sharedLookLedger.owed = false
        guard persistSharedLook() else {
            sharedLookLedger = before
            return
        }
    }

    /// Reads `gui.json` at a config load, beside the #1741
    /// crossing and ahead of anything that rewrites a profile: a
    /// stored look becomes the shared one, and a readable file
    /// without one owes the crossing. An unreadable file owes
    /// nothing, and neither does a Lua-owned config.
    func prepareSharedLook() {
        guard isGuiManaged, let config = guiConfigStore.load() else {
            sharedLookLedger = SharedLookLedger()
            return
        }
        sharedLookLedger = SharedLookLedger(
            base: config.look,
            owed: config.look == nil
        )
    }

    /// Ends an owed crossing at the first apply of a STORED
    /// profile — a built-in lends nothing: its look becomes the
    /// shared one, and every stored profile already wearing it
    /// follows it from then on. `gui.json` is written first, and
    /// only once that write landed do the profiles change, so a
    /// failed write leaves the crossing owed and every profile as
    /// it was (`SharedLookCrossingTests`).
    func adoptSharedLook(from profile: Profile) {
        guard sharedLookLedger.owed, isGuiManaged,
            profiles.list().contains(profile.name)
        else { return }
        let base = LookBody(of: profile.settings)
        sharedLookLedger.base = base
        guard persistSharedLook() else {
            sharedLookLedger.base = nil
            return
        }
        sharedLookLedger.owed = false
        for name in profiles.list() {
            guard var stored = try? profiles.read(name: name),
                stored.look == .own, base.isWorn(by: stored.settings)
            else { continue }
            stored.look = nil
            do {
                try profiles.write(stored)
            } catch {
                onLog("shared look: \(name) not rewritten: \(error)")
            }
        }
    }

    /// A stored-profile Settings Save's look half (#1752): the
    /// edited profile follows, so the draft's look is the shared
    /// one. Its own step, beside `overwriteProfile`, which writes
    /// the profile file alone.
    public func commitSharedLook(ofProfile name: String) {
        guard let saved = try? profiles.read(name: name) else { return }
        recordLookWrite(of: saved)
    }

    /// The shared look's first value when a profile opts into it
    /// before any crossing gave one: that profile's own look
    /// (`saveLookReach`). A failed write leaves none.
    func seedSharedLook(from settings: TilingSettings) {
        sharedLookLedger.base = LookBody(of: settings)
        guard persistSharedLook() else {
            sharedLookLedger.base = nil
            return
        }
        sharedLookLedger.owed = false
    }

    /// The #634 reset, which discards `gui.json` itself.
    func resetSharedLook() {
        sharedLookLedger = SharedLookLedger()
    }

    /// Writes `gui.json` with the stamp; false where nothing
    /// landed.
    @discardableResult
    private func persistSharedLook() -> Bool {
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
