import Foundation

/// KiwiVision's appearance while on (#2103 ruling 7): every move —
/// on, off, a new ask, a stop, a start — is one transition of ONE
/// ledger, judged against the appearance KiwiVision FOUND, never a
/// read taken right after its own switch, which may not have
/// landed (performed is not applied).
extension KiwiCore {
    /// Moves the system to what `ask` wants over the found
    /// appearance; a nil ask goes home. Switches only where the
    /// target differs from what was last asked, stores the debt
    /// before switching away, and clears it going home only once a
    /// switch was taken in the call — a queued fallback keeps it
    /// for the next start, which finds it paid.
    func retargetVisionAppearance(_ ask: VisionAppearance?) {
        let machine = vision.appearanceSwitch
        let now = wallClock()
        let live = machine.read()
        var debt = machine.readDebt()
        if let owed = debt, owed.overridden(by: live, at: now) {
            // The user moved it since: theirs to keep.
            _ = machine.writeDebt(nil)
            debt = nil
        }
        let base = debt?.found ?? live
        let target = ask?.wantsDark(over: base) ?? base.dark
        guard target == base.dark else {
            let away = VisionAppearanceDebt(
                found: base,
                setDark: target,
                askedAt: debt?.setDark == target
                    ? debt?.askedAt ?? now : now
            )
            guard machine.writeDebt(away) else {
                onLog("kiwivision: appearance debt not stored; no switch")
                return
            }
            if debt?.setDark != target { _ = machine.setDark(target) }
            return
        }
        guard let owed = debt else { return }
        if owed.setDark == base.dark && live.dark == base.dark {
            // A queued payment landed; its switch turned Auto off.
            if base.auto && !live.auto { machine.rearmAuto() }
            _ = machine.writeDebt(nil)
            return
        }
        let taken = machine.setDark(base.dark)
        if taken {
            // After the switch, which turns Auto off itself.
            if base.auto && !live.auto { machine.rearmAuto() }
            _ = machine.writeDebt(nil)
        } else {
            var home = owed
            home.setDark = base.dark
            home.askedAt = now
            _ = machine.writeDebt(home)
        }
    }
}
