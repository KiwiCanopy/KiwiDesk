import AppKit

/// A hidden bar's approach (#3349), split from `ShelfRevealer` at
/// the §2.1 ceiling: the pointer near an Auto bar's edge thickens
/// its handle, and a dwell, a rest on the handle or a push on a
/// free edge opens it; the outermost row of an edge macOS owns
/// hands the approach to macOS.
extension ShelfRevealer {
    /// A move over a hidden bar (#3349): the outermost row of an
    /// edge macOS owns hands the approach to macOS, and on a free
    /// edge opens the bar at once; inside the approach the handle
    /// thickens after `approachDelay`, the bar opens after
    /// `dwellDelay` from the entry, or `revealDelay` on the
    /// thickened handle.
    func hiddenMove(
        _ key: Key,
        _ target: Target,
        _ point: CGPoint
    ) {
        guard let approach = target.approach,
            let row = target.edgeRow
        else { return }
        let onRow = row.contains(point)
        guard onRow || approach.contains(point) else {
            leave(key)
            return
        }
        if ceded.contains(key) { return }
        let macOS = owned[key] ?? macEdges().owns(target.edge)
        owned[key] = macOS
        if onRow, macOS {
            cede(key)
            return
        }
        if onRow, target.flush {
            open(key)
            return
        }
        guard approach.contains(point) else {
            leave(key)
            return
        }
        if arming.contains(key) {
            handleMove(key, target, point)
            return
        }
        // Movement inside the approach never restarts the wait, or
        // a jittering pointer would never thicken it.
        guard timers[key] == nil else { return }
        arm(key, after: ShelfReveal.approachDelay) { [weak self] in
            self?.approached(key)
        }
    }

    /// The approach's wait ran out: the handle thickens, and the
    /// dwell runs on from the entry.
    fileprivate func approached(_ key: Key) {
        guard let target = targets[key], stillApproaching(key, target)
        else {
            leave(key)
            return
        }
        setArming(key, true)
        handleMove(key, target, location())
        let rest = ShelfReveal.dwellDelay - ShelfReveal.approachDelay
        arm(key, after: rest) { [weak self] in
            guard let self, let target = self.targets[key],
                self.stillApproaching(key, target)
            else { return }
            self.open(key)
        }
    }

    /// A move while the handle is thickened: resting on it opens
    /// the bar after `revealDelay`.
    fileprivate func handleMove(
        _ key: Key,
        _ target: Target,
        _ point: CGPoint
    ) {
        guard target.handle?.contains(point) == true else {
            handleTimers.removeValue(forKey: key)?.cancel()
            return
        }
        guard handleTimers[key] == nil else { return }
        handleTimers[key] = schedule(ShelfReveal.revealDelay) {
            [weak self] in
            guard let self else { return }
            self.handleTimers[key] = nil
            guard let target = self.targets[key],
                self.stillApproaching(key, target),
                target.handle?.contains(self.location()) == true
            else { return }
            self.open(key)
        }
    }

    /// Whether a timer that ran out may still act: the bar hides,
    /// gives way to no sibling, nothing was handed to macOS, a drag
    /// begun meanwhile opens no App Bar, and the pointer is still in
    /// the approach.
    fileprivate func stillApproaching(
        _ key: Key,
        _ target: Target
    ) -> Bool {
        reveal(of: key) == .hidden
            && !yields(key)
            && !ceded.contains(key)
            && (key.bar == .space || !windowMoving())
            && target.approach?.contains(location()) == true
    }

    /// Opens a hidden bar from the pointer. The reveal ends the
    /// thickening in its own pass: a redraw ahead of it would cost
    /// a full bar render more.
    fileprivate func open(_ key: Key) {
        cancelTimer(key)
        handleTimers.removeValue(forKey: key)?.cancel()
        set(.hover, for: key)
    }

    /// Hands the approach to macOS: KiwiDesk's timers end and the
    /// handle rests until the pointer leaves the approach.
    fileprivate func cede(_ key: Key) {
        cancelTimer(key)
        handleTimers.removeValue(forKey: key)?.cancel()
        ceded.insert(key)
        setArming(key, false)
    }

    /// The pointer left the approach: every wait ends and the
    /// next entry reads macOS's edges afresh.
    func leave(_ key: Key) {
        cancelTimer(key)
        handleTimers.removeValue(forKey: key)?.cancel()
        ceded.remove(key)
        owned[key] = nil
        setArming(key, false)
    }
}
