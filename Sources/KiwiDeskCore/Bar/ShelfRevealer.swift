import AppKit

/// Drives each hiding shelf's `ShelfReveal` (#761) from the
/// pointer, the show/hide action and their timers. A reveal or a
/// retract only redraws the bars (`onChange`, wired to
/// `updateBars()`): a hiding edge reserves nothing, so no reveal
/// retiles (`BarAutoHideFoldTests`).
@MainActor
final class ShelfRevealer {
    /// A hiding shelf as `updateBars()` last laid it, in Cocoa
    /// coordinates (y grows up): its strip and its screen's frame.
    struct Target: Equatable {
        let edge: AppBarEdge
        let strip: CGRect
        let screen: CGRect

        var band: CGRect { ShelfReveal.band(of: strip, edge: edge) }
        /// Where the pointer holds a shown shelf.
        var zone: CGRect { strip.union(band) }
    }

    typealias Key = ShelfManager.Key

    /// Fires when a shelf is shown or hidden.
    var onChange: @MainActor () -> Void = {}
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

    func stop() {
        running = false
        for timer in timers.values { timer.cancel() }
        timers = [:]
        syncMonitor()
    }

    /// The state of `key`, hidden where nothing revealed it.
    func reveal(of key: Key) -> ShelfReveal {
        phases[key] ?? .hidden
    }

    /// Whether `key` draws its shelf: always where it does not
    /// hide.
    func isShown(_ key: Key) -> Bool {
        targets[key] == nil || reveal(of: key).isShown
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
        let next = reveal(of: key).toggled(now: now(), duration: duration)
        set(next, for: key)
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
            return
        }
        // Movement inside the band never restarts the delay, or a
        // jittering pointer would never reveal.
        guard timers[key] == nil else { return }
        arm(key, after: ShelfReveal.revealDelay) { [weak self] in
            guard let self, let target = self.targets[key],
                self.reveal(of: key) == .hidden,
                target.band.contains(self.location())
            else { return }
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
        set(.hidden, for: key)
    }

    /// A timed pin ran out: the pointer on the shelf keeps it as
    /// a hover reveal, which retracts once the pointer leaves.
    private func pinEnded(_ key: Key) {
        guard let target = targets[key],
            case .pinned = reveal(of: key)
        else { return }
        set(target.zone.contains(location()) ? .hover : .hidden, for: key)
    }

    private func set(_ next: ShelfReveal, for key: Key) {
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

    /// Both arms, as `PointerRest`'s: moves go to the ACTIVE app,
    /// so while KiwiDesk is active only the local monitor hears.
    private static func live(
        _ deliver: @escaping @MainActor (CGPoint?) -> Void
    ) -> Any? {
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) {
            let point = $0.locationInWindow
            Task { @MainActor in deliver(point) }
        }
        let local = NSEvent.addLocalMonitorForEvents(
            matching: .mouseMoved
        ) { event in
            Task { @MainActor in deliver(nil) }
            return event
        }
        return [global, local].compactMap { $0 }
    }
}

/// A cancellable delayed call (`ShelfRevealer.schedule`).
@MainActor
final class ShelfRevealTimer {
    private var task: Task<Void, Never>?
    private let onCancel: () -> Void

    init(task: Task<Void, Never>? = nil, onCancel: @escaping () -> Void = {}) {
        self.task = task
        self.onCancel = onCancel
    }

    func cancel() {
        task?.cancel()
        task = nil
        onCancel()
    }

    /// The live schedule: a main-actor task sleeping `delay`.
    static func after(
        _ delay: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) -> ShelfRevealTimer {
        ShelfRevealTimer(
            task: Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                body()
            }
        )
    }
}
