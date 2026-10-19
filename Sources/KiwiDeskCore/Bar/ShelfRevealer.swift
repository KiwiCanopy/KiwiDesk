import AppKit

/// Drives each hiding shelf's `ShelfReveal` (#761) from the
/// pointer, the show/hide action and their timers. A reveal or a
/// retract only redraws the bars (`onChange`, wired to
/// `updateBars()`): a hiding edge reserves only its constant
/// sliver, so no reveal retiles (`BarAutoHideFoldTests`).
@MainActor
final class ShelfRevealer {
    /// A hiding shelf as `updateBars()` last laid it, in Cocoa
    /// coordinates (y grows up): its strip and its screen's frame.
    struct Target: Equatable {
        let edge: AppBarEdge
        let strip: CGRect
        let screen: CGRect
        /// The bars the shelf carries, which the action names.
        let bars: Set<ShelfBar>
        /// Where resting opens the shelf (`ShelfReveal.band`).
        var band: CGRect
        /// Where the pointer lights the mark's hover cue: around
        /// the mark, and the band.
        var near: CGRect

        init(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            bars: Set<ShelfBar>,
            band: CGRect? = nil,
            near: CGRect? = nil
        ) {
            self.edge = edge
            self.strip = strip
            self.screen = screen
            self.bars = bars
            let band = band ?? ShelfReveal.band(of: strip, edge: edge)
            self.band = band
            self.near = (near ?? band).union(band)
        }
        /// Where the pointer holds a shown shelf: the strip and its
        /// band, out to the push reach, so a pointer resting on the
        /// screen's last row is inside (`CGRect` excludes `maxY`).
        var zone: CGRect {
            strip.union(band).insetBy(
                dx: -ShelfReveal.pushReach,
                dy: -ShelfReveal.pushReach
            )
        }
    }

    typealias Key = ShelfManager.Key

    /// Fires when a shelf is shown or hidden.
    var onChange: @MainActor () -> Void = {}
    /// Whether a surface the shelf opened holds it shown although
    /// the pointer left — the hover peek, a bar menu; wired in
    /// Bootstrap. A retract it holds is asked again later.
    var holds: @MainActor (Key) -> Bool = { _ in false }
    /// Installs the mouse-moved monitors: live in production,
    /// pinned inert by both `makeTestCore` twins (tests.md ▸
    /// machine touch). A move delivered without a point is read
    /// through `location`.
    var makeMonitor:
        @MainActor (@escaping @MainActor (CGPoint?) -> Void) -> Any? =
            ShelfRevealer.live
    var removeMonitor: (Any) -> Void = { monitors in
        for monitor in monitors as? [Any] ?? [monitors] {
            NSEvent.removeMonitor(monitor)
        }
    }
    /// The pointer now, Cocoa screen space.
    var location: @MainActor () -> CGPoint = { NSEvent.mouseLocation }
    var now: @MainActor () -> Date = { Date() }
    /// Runs `body` after `delay` seconds unless the token is
    /// cancelled; a test hands a queue it drains by hand.
    var schedule:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void)
            -> ShelfRevealTimer = ShelfRevealTimer.after

    private(set) var targets: [Key: Target] = [:]
    private(set) var phases: [Key: ShelfReveal] = [:]
    /// Hidden shelves whose mark shows its hover cue — the pointer
    /// near the mark or in the band, where the reveal delay runs
    /// (#761).
    private(set) var arming: Set<Key> = []
    /// Shelves the action hid under the pointer: the hover stands
    /// down until the pointer leaves the shelf.
    private var suppressed: Set<Key> = []
    private var timers: [Key: ShelfRevealTimer] = [:]
    private var monitor: Any?
    private var running = false

    func start() {
        running = true
        syncMonitor()
    }

    /// Ends every reveal: a stopped core owes no timer, and a pin
    /// left without one would never end. Silent — the core is
    /// tearing its bars down, and its next start redraws them.
    func stop() {
        running = false
        for timer in timers.values { timer.cancel() }
        timers = [:]
        suppressed = []
        phases = [:]
        arming = []
        syncMonitor()
    }

    /// The state of `key`, hidden where nothing revealed it.
    func reveal(of key: Key) -> ShelfReveal {
        phases[key] ?? .hidden
    }

    /// The hiding shelves of this pass; a shelf that stopped
    /// hiding forgets its state.
    func sync(_ next: [Key: Target]) {
        for key in targets.keys where next[key] == nil {
            forget(key)
        }
        targets = next
        syncMonitor()
    }

    /// The show/hide action on `key`'s shelf; false where that
    /// shelf does not hide. `duration` is
    /// `kiwishelf.reveal_duration`.
    @discardableResult
    func toggle(_ key: Key, duration: TimeInterval) -> Bool {
        guard let target = targets[key] else { return false }
        cancelTimer(key)
        arming.remove(key)
        let next = reveal(of: key).toggled(now: now(), duration: duration)
        set(next, for: key)
        if next.isShown { suppressed.remove(key) }
        if next == .hidden {
            if target.zone.contains(location()) { suppressed.insert(key) }
        } else if case .pinned(let until?) = next {
            arm(key, after: until.timeIntervalSince(now())) { [weak self] in
                self?.pinEnded(key)
            }
        }
        return true
    }

    /// One pointer move, Cocoa screen space.
    func moved(to point: CGPoint) {
        for (key, target) in targets {
            if suppressed.contains(key) {
                if !target.zone.contains(point) { suppressed.remove(key) }
                continue
            }
            switch reveal(of: key) {
            case .hidden: hiddenMove(key, target, point)
            case .hover: hoverMove(key, target, point)
            case .pinned: break
            }
        }
    }

    private func hiddenMove(_ key: Key, _ target: Target, _ point: CGPoint) {
        if ShelfReveal.pushes(
            point,
            strip: target.strip,
            edge: target.edge,
            screen: target.screen
        ) {
            cancelTimer(key)
            set(.hover, for: key)
            return
        }
        guard target.band.contains(point) else {
            cancelTimer(key)
            // Near the mark lights its cue; only the band opens it.
            setArming(key, target.near.contains(point))
            return
        }
        // Movement inside the band never restarts the delay, or a
        // jittering pointer would never reveal.
        setArming(key, true)
        guard timers[key] == nil else { return }
        arm(key, after: ShelfReveal.revealDelay) { [weak self] in
            guard let self else { return }
            guard let target = self.targets[key],
                self.reveal(of: key) == .hidden,
                target.band.contains(self.location())
            else {
                let near = self.targets[key]?.near
                self.setArming(key, near?.contains(self.location()) == true)
                return
            }
            // The reveal ends the hover in its own pass: a redraw
            // of the plate ahead of it would shrink the plate the
            // shelf grows out of, a full bar render earlier.
            self.set(.hover, for: key)
        }
    }

    private func hoverMove(_ key: Key, _ target: Target, _ point: CGPoint) {
        guard !target.zone.contains(point) else {
            cancelTimer(key)
            return
        }
        guard timers[key] == nil else { return }
        arm(key, after: ShelfReveal.retractDelay) { [weak self] in
            self?.retractIfLeft(key)
        }
    }

    /// The retract delay ran out: a pointer the monitor could not
    /// hear — over KiwiDesk's own panel — is read here.
    private func retractIfLeft(_ key: Key) {
        guard let target = targets[key], reveal(of: key) == .hover
        else { return }
        if target.zone.contains(location()) { return }
        guard !holds(key) else {
            arm(key, after: ShelfReveal.retractDelay) { [weak self] in
                self?.retractIfLeft(key)
            }
            return
        }
        set(.hidden, for: key)
    }

    /// A timed pin ran out: the pointer on the shelf keeps it as
    /// a hover reveal, which retracts once the pointer leaves.
    private func pinEnded(_ key: Key) {
        guard let target = targets[key],
            case .pinned = reveal(of: key)
        else { return }
        if target.zone.contains(location()) {
            set(.hover, for: key)
        } else if holds(key) {
            // Its menu or peek is up: retract once that closes.
            set(.hover, for: key)
            arm(key, after: ShelfReveal.retractDelay) { [weak self] in
                self?.retractIfLeft(key)
            }
        } else {
            set(.hidden, for: key)
        }
    }

    /// Marks `key` arming or not, reporting a change.
    private func setArming(_ key: Key, _ armed: Bool) {
        guard arming.contains(key) != armed else { return }
        if armed { arming.insert(key) } else { arming.remove(key) }
        onChange()
    }

    private func set(_ next: ShelfReveal, for key: Key) {
        if next.isShown { arming.remove(key) }
        let was = reveal(of: key).isShown
        phases[key] = next == .hidden ? nil : next
        if was != next.isShown { onChange() }
    }

    private func arm(
        _ key: Key,
        after delay: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) {
        timers[key] = schedule(max(0, delay)) { [weak self] in
            self?.timers[key] = nil
            body()
        }
    }

    private func cancelTimer(_ key: Key) {
        timers.removeValue(forKey: key)?.cancel()
    }

    private func forget(_ key: Key) {
        cancelTimer(key)
        arming.remove(key)
        phases[key] = nil
        suppressed.remove(key)
    }

    /// The monitor is installed only while a shelf hides, so an
    /// `always` setup costs no event per pointer move.
    private func syncMonitor() {
        if running, !targets.isEmpty {
            guard monitor == nil else { return }
            monitor = makeMonitor { [weak self] point in
                guard let self else { return }
                self.moved(to: point ?? self.location())
            }
        } else if let monitor {
            removeMonitor(monitor)
            self.monitor = nil
        }
    }

    var isListening: Bool { monitor != nil }
}
