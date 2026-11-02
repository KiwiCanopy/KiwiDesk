import Foundation

extension KiwiCore {
    /// Whether a per-Space session-store heal stands down over
    /// `members` (#2907): inside a Desktop switch's grace, or
    /// while a member is a window no shown Desktop hosts. Through
    /// a switch the Space holds both Desktops' members until the
    /// departing apps' destroys land, some several switches late,
    /// and a heal over that mix wrote the shared ratio for a
    /// layout no Desktop shows, ratcheting it (device,
    /// 2026-11-02). A nil read counts as shown. One SkyLight host
    /// read per member, outside the grace. It never decides
    /// membership, the away ledger or a sweep.
    func healStandsDown(for members: [WindowID]) -> Bool {
        let sinceSwitch = Date().timeIntervalSince(lastDesktopSwitch)
        if sinceSwitch >= 0,
            sinceSwitch < EventLoop.spaceSwitchCoalesceGrace
        {
            return true
        }
        return members.contains { windowIsOnShownDesktop($0) == false }
    }
}
