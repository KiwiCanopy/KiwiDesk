import Foundation

extension StateCoordinator {
    /// Swaps a window ID across every ID-keyed map for native tab
    /// switches (#308) — the hand-mirrored list §5 warns about, so
    /// `WindowRekeyParityTests` discovers the containers by
    /// reflection. `minimizeOrder`'s element is a struct the
    /// reflection cannot see; the `String(describing:)` scan and
    /// `MinimizeOrderTests` are its nets (#673).
    /// `rememberedFloating` is keyed by app+title and deliberately
    /// untouched.
    mutating func rekey(_ old: WindowID, to new: WindowID) {
        windows.rekey(old, to: new)
        workspaces.rekey(old, to: new)
        if let space = rememberedSpaces.removeValue(forKey: old) {
            rememberedSpaces[new] = space
        }
        if closedDepartures.remove(old) != nil {
            closedDepartures.insert(new)
        }
        if unjudgedFilings.remove(old) != nil {
            unjudgedFilings.insert(new)
        }
        if let stamp = titledRulePending.removeValue(forKey: old) {
            titledRulePending[new] = stamp
        }
        if let owed = restoredFrames.removeValue(forKey: old) {
            restoredFrames[new] = owed
        }
        if crossSession.placed.remove(old) != nil {
            crossSession.placed.insert(new)
        }
        if let slot = departedSlots.removeValue(forKey: old) {
            departedSlots[new] = slot
        }
        for (id, slot) in departedSlots where slot.handedTo == old {
            departedSlots[id]?.handedTo = new
        }
        if let away = awayWindows.removeValue(forKey: old) {
            awayWindows[new] = away.withID(new)
        }
        if let index = minimizeOrder.firstIndex(where: { $0.id == old }) {
            minimizeOrder[index].id = new
        }
        if userFloated.remove(old) != nil {
            userFloated.insert(new)
        }
        if let reach = stickyReachOverrides.removeValue(forKey: old) {
            stickyReachOverrides[new] = reach
        }
        rekeyFloatMemory(old, to: new)
        if let rank = focusRecency.removeValue(forKey: old) {
            focusRecency[new] = rank
        }
        rekeyPocket(old, to: new)
        rekeyVisionFill(old, to: new)
    }
}
