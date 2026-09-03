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
/// failed. The write therefore mints the identity into the
/// snapshot it RETURNS — we know what we wrote — and the next
/// call confirms it against the WindowServer. A Desktop still
/// unstamped there is unstampable for this process and every
/// consumer falls back to its number. No polling: it would spend
/// the main actor every handler shares, to learn what the next
/// read tells us for nothing.
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
            guard
                WMBridge.setValues(
                    [DesktopIdentity.storeKey: identity.raw],
                    of: space.id
                )
            else { continue }
            desktopMemory.stampAttempts.insert(space.id)
            minted[space.id] = identity
        }
        guard !minted.isEmpty else { return snapshot }
        return snapshot.stamping(minted)
    }
}

extension DesktopSnapshot {
    /// This snapshot with identities we just wrote folded in —
    /// the read door cannot see them yet (P3's ~7 ms), and a
    /// caller must not resolve the same topology two ways inside
    /// one handler.
    func stamping(
        _ minted: [SkyLight.SpaceID: DesktopIdentity]
    ) -> DesktopSnapshot {
        DesktopSnapshot(
            authority: authority,
            mainUUID: mainUUID,
            mainCurrentSpace: mainCurrentSpace,
            currentSpaces: currentSpaces,
            spaces: spaces.map { space in
                guard let identity = minted[space.id] else {
                    return space
                }
                return NativeSpace(
                    id: space.id,
                    displayUUID: space.displayUUID,
                    isCurrent: space.isCurrent,
                    isUser: space.isUser,
                    identity: identity
                )
            }
        )
    }
}
