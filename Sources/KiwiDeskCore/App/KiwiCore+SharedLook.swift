import Foundation

/// The shared look's state (#1752).
struct SharedLookLedger {
    /// The look `gui.json` carries; nil before one is adopted.
    var base: LookBody?
    /// Whether the crossing is owed: a readable, GUI-managed
    /// `gui.json` that carries no look yet.
    var owed = false

    /// Whether the motion crossing is owed (#2176): a shared look
    /// missing a motion path — adopted before animations joined it,
    /// or before a field was added. Derived from the look, so the
    /// write that completes it is what ends it.
    var motionOwed: Bool {
        guard let base else { return false }
        return LookKeys.motion.contains { base.style[$0] == nil }
    }
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
        sharedLook?.worn(over: settings) ?? settings
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
    /// profile — `apply(profile:)`, or `applyStandard` saving one
    /// — a built-in lends nothing: its look becomes the shared one
    /// (`crossWith`); once one exists, the same apply of a follower
    /// settles an owed motion crossing (`settleSharedMotion`).
    func adoptSharedLook(from profile: Profile) {
        guard isGuiManaged, profiles.list().contains(profile.name)
        else { return }
        guard sharedLookLedger.owed else {
            settleSharedMotion(electing: profile)
            return
        }
        crossWith(LookBody(of: profile.settings))
    }

    /// The motion crossing (#2176): the shared look takes, for each
    /// motion path it lacks, the value of `source` — a stored
    /// profile that FOLLOWS it, at its first apply or its first look
    /// write — and every other follower that then runs different
    /// animations keeps its own look, frozen as it ran, so no stored
    /// profile's animations move. An own `source` elects nothing and
    /// leaves the crossing owed; an own profile is never touched.
    /// `gui.json` first; a failed write leaves it owed and every
    /// profile as it was (`SharedLookMotionTests`).
    func settleSharedMotion(electing source: Profile) {
        guard sharedLookLedger.motionOwed, source.look == nil,
            let before = sharedLook
        else { return }
        var base = before
        base.style.merge(
            LookKeys.extract(from: source.settings, paths: LookKeys.motion)
        ) { kept, _ in kept }
        let ledger = sharedLookLedger
        sharedLookLedger.base = base
        guard persistSharedLook() else {
            sharedLookLedger = ledger
            return
        }
        let motion = base.style.filter { LookKeys.motion.contains($0.key) }
        for name in profiles.list() where name != source.name {
            guard var stored = try? profiles.read(name: name),
                stored.look == nil
            else { continue }
            let ran = before.worn(over: stored.settings)
            let ranMotion = LookKeys.extract(
                from: ran,
                paths: LookKeys.motion
            )
            guard ranMotion != motion else { continue }
            stored.settings = ran
            stored.look = .own
            do {
                try profiles.write(stored)
            } catch {
                onLog("shared look: \(name) not frozen: \(error)")
            }
        }
    }

    /// The crossing's election: `base` becomes the shared look, and
    /// every stored profile follows it exactly where it already
    /// wears it — an own twin starts following, and a profile born
    /// following before any shared look existed but wearing another
    /// keeps its own — so nothing on screen moves. `gui.json` is
    /// written first, and only once that write landed do the
    /// profiles change, so a failed write leaves the crossing owed
    /// and every profile as it was (`SharedLookCrossingTests`).
    func crossWith(_ base: LookBody) {
        let before = sharedLookLedger
        sharedLookLedger.base = base
        guard persistSharedLook() else {
            sharedLookLedger = before
            return
        }
        sharedLookLedger.owed = false
        for name in profiles.list() {
            guard var stored = try? profiles.read(name: name) else {
                continue
            }
            let follows: LookReference? =
                base.isWorn(by: stored.settings) ? nil : .own
            guard stored.look != follows else { continue }
            stored.look = follows
            do {
                try profiles.write(stored)
            } catch {
                onLog("shared look: \(name) not rewritten: \(error)")
            }
        }
    }

    /// A restore takes the bundle's shared look, ahead of the
    /// `gui.json` write that stamps it; a bundle from before #1752
    /// has none, so the crossing is owed again and elects among its
    /// profiles, which its step stamped own.
    func takeRestoredSharedLook(from bundle: SetupBundle) {
        let look = bundle.config?.look
        sharedLookLedger = SharedLookLedger(base: look, owed: look == nil)
    }

    /// The #634 reset, which discards `gui.json` itself.
    func resetSharedLook() {
        sharedLookLedger = SharedLookLedger()
    }
}
