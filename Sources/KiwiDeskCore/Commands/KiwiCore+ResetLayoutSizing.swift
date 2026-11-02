import Foundation

/// `reset_layout_sizing([space])` (#764): drops a Space's SIZING
/// — what `resize` accumulates — so it lands on what its profile
/// authored, structure kept: the active Space by default, one
/// named by id, or every Space for `all` (owner ruling
/// 2026-09-21). What counts as sizing is `Space.resetSizing`'s
/// and the session ratios', never stated here; a named Space
/// resets on the Desktop shown now, `all` on every Desktop
/// (#2921 ruling 2).
extension KiwiCore {
    /// The spelling that names every Space.
    static let everySpace = "all"

    /// Dispatched through `settingsCommand`, so the one trailing
    /// `.apply` retile in `layoutCommand` shows the reset.
    func resetLayoutSizing(_ args: [JSONValue]) -> CommandResponse {
        let targets: [SpaceID]
        var everyDesktop = false
        if let raw = args.first?.stringValue, !raw.isEmpty {
            if raw == Self.everySpace {
                targets = state.workspaces.allSpaces.map(\.id)
                everyDesktop = true
            } else {
                let space = SpaceID(raw)
                guard state.workspaces[space] != nil else {
                    return .fail("unknown space: \(raw)")
                }
                targets = [space]
            }
        } else {
            guard let active = state.workspaces.activeSpace else {
                return .fail("no active space")
            }
            targets = [active]
        }
        if everyDesktop {
            clearSessionRatios { $0 = SessionRatios() }
        }
        for space in targets {
            if !everyDesktop { resetSessionRatios(of: space) }
            state.workspaces.withSpace(space) {
                $0.resetSizing()
                // The slots it re-divides are hidden under a
                // maximized window (#2448).
                $0.maximized = nil
            }
        }
        // Only room is re-divided among windows already placed
        // (#593). A cleared track weight can change which windows
        // overlap, and the retile is the dispatcher's trailer, so
        // the restore is RECORDED for it rather than armed here —
        // armed now it would run off the pre-reset frames (#153,
        // #674).
        promiseAllWindowsSpringSized()
        if activeTrackOverflows {
            requestZOrderRestoreAfterDispatch()
        }
        return .ok()
    }
}
