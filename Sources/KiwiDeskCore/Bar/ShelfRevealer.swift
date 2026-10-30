import AppKit

/// Drives each hiding bar's `ShelfReveal` (#761) from the
/// pointer, its shortcut and their timers — one target per bar, so
/// a shortcut shows only the bar it names. A reveal or a retract
/// only redraws the bars (`onChange`, wired to `updateBars()`): a
/// hiding edge reserves only its constant sliver and a hidden bar
/// nothing, so no reveal retiles (`BarAutoHideFoldTests`).
@MainActor
final class ShelfRevealer {
    /// One hiding bar: the shelf it sits on and which bar.
    struct Key: Hashable {
        let shelf: ShelfManager.Key
        let bar: ShelfBar
    }

    /// Fires when a shelf is shown or hidden.
    var onChange: @MainActor () -> Void = {}
    /// Whether a surface the shelf opened holds it shown although
    /// the pointer left — the hover peek, a bar menu; wired in
    /// Bootstrap. A retract it holds is asked again later.
    var holds: @MainActor (ShelfManager.Key) -> Bool = { _ in false }
    /// Installs the pointer monitors (`heard`): live in
    /// production, pinned inert by both `makeTestCore` twins
    /// (tests.md ▸ machine touch). A move delivered without a
    /// point is read through `location`; the flag is a left drag.
    var makeMonitor:
        @MainActor (@escaping @MainActor (CGPoint?, Bool) -> Void)
            -> Any? = ShelfRevealer.live
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

    /// Every hiding bar reads shown while set — the tour's looks
    /// step (#2515) — over whatever its pointer or shortcut did,
    /// which stands again on release.
    var heldOpen = false {
        didSet { if running, heldOpen != oldValue { onChange() } }
    }

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
        heldOpen = false
        for timer in timers.values { timer.cancel() }
        timers = [:]
        suppressed = []
        phases = [:]
        arming = []
        syncMonitor()
    }

    /// Whether `key`'s bar stands aside: hidden while a sibling on
    /// its shelf shows, so the mouse opens one bar at a time (owner,
    /// 2026-10-19) — its band opens nothing and its mark gives way.
    /// Only a shortcut shows it, beside the sibling.
    func yields(_ key: Key) -> Bool {
        reveal(of: key) == .hidden
            && phases.keys.contains { $0.shelf == key.shelf && $0 != key }
    }

    /// The state of `key`, hidden where nothing revealed it.
    func reveal(of key: Key) -> ShelfReveal {
        if heldOpen, targets[key] != nil { return .pinned(until: nil) }
        return phases[key] ?? .hidden
    }

    /// Whether any hiding bar sits on `shelf`, which a retracted
    /// shelf's panel is kept for.
    func hasTarget(on shelf: ShelfManager.Key) -> Bool {
        targets.keys.contains { $0.shelf == shelf }
    }

    /// The bars `edge` draws on `display` this pass: those shown at
    /// rest, and each a reveal shows (#761) — the one answer the
    /// live plan takes.
    func drawn(_ edge: ShelfEdge, display: DisplayID) -> Set<ShelfBar> {
        let shelf = ShelfManager.Key(display: display, edge: edge.edge)
        return edge.drawnAtRest.union(
            edge.bars.keys.filter {
                reveal(of: Key(shelf: shelf, bar: $0)).isShown
            }
        )
    }

    /// The hiding bars of this pass; a bar that stopped hiding
    /// forgets its state.
    func sync(_ next: [Key: Target]) {
        for key in targets.keys where next[key] == nil {
            forget(key)
        }
        targets = next
        syncMonitor()
    }

    /// The show/hide action on `key`'s bar; false where that bar
    /// does not hide or while `heldOpen`. `duration` is
    /// `kiwishelf.reveal_timeout`.
    @discardableResult
    func toggle(_ key: Key, duration: TimeInterval) -> Bool {
        // Under a hold the bar reads shown whatever its phase,
        // so a toggle could only move what the release gives back.
        guard !heldOpen, let target = targets[key] else {
            return false
        }
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

    /// One pointer move, Cocoa screen space. A drag's move opens
    /// only a Space Bar, its drop targets (#2795); it holds and
    /// retracts any shown bar as a move does.
    func moved(to point: CGPoint, dragging: Bool = false) {
        for (key, target) in targets where target.hovers {
            if suppressed.contains(key) {
                if !target.zone.contains(point) { suppressed.remove(key) }
                continue
            }
            switch reveal(of: key) {
            // Asked per target: a sibling this move revealed — a
            // push at the seam of two bands — stands this one down.
            case .hidden where yields(key),
                .hidden where dragging && key.bar != .space:
                cancelTimer(key)
                setArming(key, false)
            case .hidden: hiddenMove(key, target, point)
            case .hover: hoverMove(key, target, point)
            case .pinned: break
            }
        }
    }

    private func hiddenMove(_ key: Key, _ target: Target, _ point: CGPoint) {
        guard let band = target.band else { return }
        if ShelfReveal.pushes(
            point,
            band: band,
            strip: target.strip,
            edge: target.edge,
            screen: target.screen
        ) {
            cancelTimer(key)
            set(.hover, for: key)
            return
        }
        guard band.contains(point) else {
            cancelTimer(key)
            // Near the mark lights its cue; only the band opens it.
            setArming(key, target.near?.contains(point) == true)
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
                !self.yields(key),
                target.band?.contains(self.location()) == true
            else {
                let near = self.targets[key]?.near
                self.setArming(
                    key,
                    !self.yields(key)
                        && near?.contains(self.location()) == true
                )
                return
            }
            // The reveal ends the hover in its own pass: a redraw
            // ahead of it would cost a full bar render more.
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
        // A band-less bar is held by its zone only while the pointer
        // can re-open it, which it cannot (#761).
        if target.hovers, target.zone.contains(location()) { return }
        guard !holds(key.shelf) else {
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
        if target.hovers, target.zone.contains(location()) {
            set(.hover, for: key)
        } else if holds(key.shelf) {
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

    /// The monitor is installed only while a bar the pointer can
    /// open hides, so an `always` or `hidden` setup costs no event
    /// per pointer move.
    private func syncMonitor() {
        if running, targets.values.contains(where: \.hovers) {
            guard monitor == nil else { return }
            monitor = makeMonitor { [weak self] point, dragging in
                guard let self else { return }
                self.moved(
                    to: point ?? self.location(),
                    dragging: dragging
                )
            }
        } else if let monitor {
            removeMonitor(monitor)
            self.monitor = nil
        }
    }

    var isListening: Bool { monitor != nil }
}
