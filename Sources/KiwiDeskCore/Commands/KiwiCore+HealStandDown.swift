import Foundation

extension KiwiCore {
    /// Whether a per-Space session-store heal stands down over
    /// `members` (#2907): inside a Desktop switch's grace, or
    /// while a member is a window no shown Desktop hosts. Through
    /// a switch the Space holds both Desktops' members until the
    /// departing apps' destroys land, some several switches late,
    /// and a heal over that mix wrote the shared ratio for a
    /// layout no Desktop shows, ratcheting it (device,
    /// 2026-11-02). A stand-down inside the grace owes the
    /// ordinary pass after it, through the apply heal's slot, so a
    /// quiet switch still heals. Outside the grace, one topology
    /// read and one host read per member. It never decides
    /// membership, the away ledger or a sweep.
    func healStandsDown(for members: [WindowID]) -> Bool {
        let sinceSwitch = Date().timeIntervalSince(lastDesktopSwitch)
        if sinceSwitch >= 0,
            sinceSwitch < EventLoop.spaceSwitchCoalesceGrace
        {
            oweApplyHealPass()
            return true
        }
        return desktopMemory.readOffShown(members)
    }
}
