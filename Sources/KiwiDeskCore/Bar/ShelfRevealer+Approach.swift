import AppKit

/// A hidden bar's approach (#3349, #3360), split from
/// `ShelfRevealer` at the §2.1 ceiling: the pointer near an Auto
/// bar's edge runs a fill along its handle, and the bar opens as
/// the fill completes — the dwell, hurried by a rest on the handle
/// — or at once on a push against a free edge; the outermost row of
/// an edge macOS owns hands the approach to macOS.
extension ShelfRevealer {
    /// A move over a hidden bar (#3349, #3360): the outermost row
    /// of an edge macOS owns hands the approach to macOS, and on a
    /// free edge opens the bar at once; entering the approach starts
    /// the fill at the handle's point nearest the pointer, and the
    /// bar opens `dwellDelay` after the entry, or `revealDelay`
    /// after the pointer reaches the handle's hover band.
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
        if let fill = fills[key] {
            handleMove(key, target, point, fill)
            return
        }
        // The entry: moving on keeps the fill's start (#3360 ▸ 7).
        // One that lands on the hover band is hurried at once, the
        // fill set once so its first draw runs from its start.
        let entered = now()
        let onBand = target.handle?.contains(point) == true
        setFill(
            key,
            .init(
                origin: target.fillOrigin(at: point),
                started: entered,
                until: entered.addingTimeInterval(
                    onBand
                        ? min(ShelfReveal.revealDelay, ShelfReveal.dwellDelay)
                        : ShelfReveal.dwellDelay
                )
            )
        )
        arm(key, after: ShelfReveal.dwellDelay) { [weak self] in
            guard let self else { return }
            guard let target = self.targets[key],
                self.stillApproaching(key, target)
            else {
                // Unheard leaves — a drag moving no window, a bar
                // turned Hidden — end the fill here.
                self.leave(key)
                return
            }
            self.open(key)
        }
        if onBand { armHandle(key) }
    }

    /// A move while the fill runs: reaching the hover band hurries
    /// it on, the bar opening `revealDelay` later unless the dwell
    /// ends first; the pocket's rise goes on at the fast pace from
    /// where it stands (#3368 ruling 3).
    fileprivate func handleMove(
        _ key: Key,
        _ target: Target,
        _ point: CGPoint,
        _ fill: ShelfHandleSpec.Fill
    ) {
        guard handleTimers[key] == nil,
            target.handle?.contains(point) == true
        else { return }
        let rested = now()
        let next =
            key.isPocket
            ? PocketRiseTimeline.hurried(fill, at: rested)
            : .init(
                origin: fill.origin,
                started: rested,
                until: rested.addingTimeInterval(ShelfReveal.revealDelay)
            )
        guard next.until < fill.until else { return }
        setFill(key, next)
        armHandle(
            key,
            after: key.isPocket ? next.length : ShelfReveal.revealDelay
        )
    }

    /// Opens the bar `delay` from now, while it still hides.
    fileprivate func armHandle(
        _ key: Key,
        after delay: TimeInterval = ShelfReveal.revealDelay
    ) {
        handleTimers[key] = schedule(delay) {
            [weak self] in
            guard let self else { return }
            self.handleTimers[key] = nil
            guard let target = self.targets[key],
                self.stillApproaching(key, target)
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
    /// fill in its own pass: a redraw ahead of it would cost a full
    /// bar render more.
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
        setFill(key, nil)
    }

    /// The pointer left the approach: every wait ends and the
    /// next entry reads macOS's edges afresh.
    func leave(_ key: Key) {
        cancelTimer(key)
        handleTimers.removeValue(forKey: key)?.cancel()
        ceded.remove(key)
        owned[key] = nil
        setFill(key, nil)
    }
}
