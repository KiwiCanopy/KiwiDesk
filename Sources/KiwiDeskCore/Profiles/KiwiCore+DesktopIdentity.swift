import Foundation

/// Stamping a KiwiDesk identity onto every user Desktop (#1147),
/// so durable per-Desktop state files under something a renumber
/// cannot move. The WRITE is the only part that needs the bridge;
/// every read rides the topology snapshot (`NativeSpaces.parse`).
///
/// **The verify is deferred by one snapshot, and that is a
/// measurement rather than a preference** (probe P3,
/// 2026-09-03): the plist shows a freshly written key only after
/// ~7 ms, so an immediate re-read reports every fresh stamp as
/// failed. No polling either — it would spend the main actor
/// every handler shares to learn what the next read gives for
/// nothing. The next call confirms the write instead, and a
/// Desktop still unstamped there is unstampable for this process.
///
/// **So this returns the CONFIRMED reading, never an optimistic
/// one.** A dispatched write is not an applied one (#884/#889),
/// and a snapshot carrying identities the WindowServer has not
/// acknowledged hands every caller a key no later reading can
/// name: `lastDesktop`, the Space memory and a fresh binding
/// would each file under an orphan. A Desktop stamped this
/// instant therefore keys by its NUMBER for exactly one call and
/// by its identity forever after — which is the same fallback a
/// bridgeless host lives on permanently, so it is a path already
/// walked rather than a special case (architect review,
/// 2026-09-04).
extension KiwiCore {
    /// The topology, with every user Desktop stamped that can be.
    ///
    /// A handler takes this INSTEAD of
    /// `NativeSpaces.desktopSnapshot()` and then answers every
    /// question from it, the #888 one-reading rule unchanged.
    func stampedDesktopSnapshot() -> DesktopSnapshot {
        let snapshot = NativeSpaces.desktopSnapshot()
        var minted: [SkyLight.SpaceID: DesktopIdentity] = [:]
        for space in snapshot.spaces where space.isUser {
            if space.identity != nil {
                // It landed — a pending attempt is answered, and
                // a Desktop can leave the unstampable set if
                // something else stamped it since.
                desktopMemory.stampAttempts.remove(space.id)
                desktopMemory.unstampable.remove(space.id)
                continue
            }
            if desktopMemory.stampAttempts.contains(space.id) {
                // We wrote, and the WindowServer does not have
                // it. Performed is not applied (#884/#889).
                desktopMemory.stampAttempts.remove(space.id)
                desktopMemory.unstampable.insert(space.id)
                onLog(
                    "desktop identity: space \(space.id) did not "
                        + "keep its stamp; falling back to its "
                        + "Mission Control number"
                )
                continue
            }
            guard !desktopMemory.unstampable.contains(space.id),
                canDriveDesktops
            else { continue }
            let identity = DesktopIdentity.mint()
            guard desktopMemory.writeStamp(space.id, identity)
            else {
                // A REFUSED dispatch is one attempt too, or this
                // re-mints and re-dispatches on every snapshot
                // for the life of the process.
                desktopMemory.unstampable.insert(space.id)
                continue
            }
            desktopMemory.stampAttempts.insert(space.id)
            minted[space.id] = identity
        }
        // The re-key rides HERE rather than at each of the four
        // callers: a caller that forgot would leave an entry
        // keyed by a number for the life of the session with
        // nothing to say so (#1147).
        reconcileDesktopBindings(in: snapshot)
        // Same reason, same reading: the Space memory is filed
        // under the key this snapshot answers to, or a freshly
        // stamped Desktop loses the Space it was left on (#1230).
        reconcileDesktopSpaceMemory(in: snapshot)
        return snapshot
    }

    /// The live stamp write — the ONE production bridge call on
    /// this path, and the reason it is a seam rather than an
    /// inline call: a fixture space id IS a real Desktop id on
    /// the host (Desktop 1 is id 1), so an unpinned suite that
    /// switches Desktops would stamp the developer's own
    /// (tests.md; `makeTestCore` pins it, and the stamping suite
    /// takes it back with the bridge itself faked).
    static func liveStampWrite(
        _ space: SkyLight.SpaceID,
        _ identity: DesktopIdentity
    ) -> Bool {
        WMBridge.setValues(
            [DesktopIdentity.storeKey: identity.raw],
            of: space
        )
    }
}
