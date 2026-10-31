import AppKit

/// The one subscription to WindowServer's per-window events
/// (#2275): each overlay family registers the windows it wants
/// under its own `Consumer`, the watch requests their union, and
/// an event's frames and hides fan out at once, in `Consumer`
/// declaration order (borders.md ▸ KiwiVision). Its restack is
/// owed to `atTurnEnd` and paid there once per window, in the same
/// order, skipping a consumer whose hide landed since (#2659).
@MainActor
public final class WindowServerWatch {
    /// Declaration order IS the fan-out order in every phase: the
    /// mark re-asserts before the ring orders, so the mark stays
    /// above a front ring, and the plate restacks after the ring,
    /// which it stacks under. KiwiVision's consumer also hears the
    /// float tier, whose landing re-enters the fan-out for the
    /// target (`KiwiCore.visionWindowRestacked`).
    enum Consumer: CaseIterable {
        case mark, overflow, ring, vision
    }

    /// What a consumer does with an event; a nil hook is a phase
    /// it takes no part in.
    struct Hooks {
        /// A window's WindowServer bounds, read once per event and
        /// never while our own animation drives it; `unhiding` is
        /// set for the unhide event, whose restack follows.
        var frame: (@MainActor (WindowID, CGRect, _ unhiding: Bool) -> Void)?
        var restack: (@MainActor (WindowID) -> Void)?
        var hide: (@MainActor (WindowID) -> Void)?
    }

    /// Whether the WindowServer stream is up for the last request.
    public private(set) var isActive = false
    /// QA lever forcing the AX-fallback path (#596), set from
    /// `KIWIDESK_NO_WS_TRACKING` at wiring.
    var trackingDisabled = false
    /// True while our own animation drives a window (#594).
    var isAnimating: @MainActor (WindowID) -> Bool = { _ in false }
    /// WindowServer bounds query seam; a test core pins it. Two
    /// readers: the watch skips a frame on nil, and the float
    /// raise's `floatIsDrawn` (#2840) keeps the window on nil.
    var readWindowBounds: @MainActor (WindowID) -> CGRect? = {
        SkyLight.windowBounds($0.raw)
    }
    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Where an event's owed restack is paid. Bootstrap wires the
    /// run loop turn's end, so the reorder and unhide one raise
    /// sends order a ring once (#2659); unwired, it pays at once.
    var atTurnEnd: @MainActor (@escaping @MainActor () -> Void) -> Void =
        { $0() }
    #if DEBUG
        /// Test-only: stands in for the WindowServer request.
        /// Production must not set it.
        var override: ((Set<WindowID>) -> Bool)?

        /// Test-only: forces the stream's verdict until the next
        /// request. Production must not call it.
        func setActive(_ active: Bool) { isActive = active }
    #endif

    private var hooks: [Consumer: Hooks] = [:]
    private var heard: [Consumer: Set<WindowID>] = [:]
    private var kept: [Consumer: Set<WindowID>] = [:]
    private var started = false
    private var source: SkyLightWindowEvents?
    /// Whether the pump was ever asked for; the lever keeps it
    /// false, since a live stream would heal the drift it exposes.
    private(set) var triedSource = false
    private var reported: Bool?
    /// Windows whose event owes a restack this turn, in arrival
    /// order, and the consumers whose hide landed since.
    private var owedRestacks: [WindowID] = []
    private var hiddenSinceOwed: [WindowID: Set<Consumer>] = [:]
    private var paymentScheduled = false

    public init() {}

    /// Connects `consumer`'s hooks; once per consumer at wiring.
    func connect(_ consumer: Consumer, _ hooks: Hooks) {
        self.hooks[consumer] = hooks
    }

    /// Replaces `consumer`'s windows: `heard` are delivered,
    /// `kept` are requested and never delivered — the ring's
    /// dormant rings, so a Space switch leaves the request
    /// unchanged (#1925). Re-submits every time, so a failed
    /// request retries at the next one.
    func request(
        _ heard: Set<WindowID>,
        for consumer: Consumer,
        keeping kept: Set<WindowID> = []
    ) {
        self.heard[consumer] = heard
        self.kept[consumer] = kept
        submit()
    }

    /// The windows `consumer` last asked to hear.
    func requested(by consumer: Consumer) -> Set<WindowID> {
        heard[consumer] ?? []
    }

    /// Whether the stream delivers `id`'s events to `consumer`.
    func hears(_ id: WindowID, as consumer: Consumer) -> Bool {
        isActive && heard[consumer]?.contains(id) == true
    }

    /// Configures tracking from the environment
    /// (`KIWIDESK_NO_WS_TRACKING`, #596): unlike
    /// `KIWIDESK_STRAND_LOG`, it kills a production fast path for
    /// the whole run.
    func configureFromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) {
        let value = environment["KIWIDESK_NO_WS_TRACKING"]
        trackingDisabled = !(value?.isEmpty ?? true)
    }

    /// Enables the private stream after application startup.
    func start() {
        started = true
        source?.attach(self)
    }

    /// Drops every registration and the stream, silently.
    func stop() {
        heard = [:]
        kept = [:]
        owedRestacks = []
        hiddenSinceOwed = [:]
        paymentScheduled = false
        // A best-effort clear outside the verdict path: a quit
        // reports no tracking state.
        if started { _ = source?.watch([]) }
        started = false
        isActive = false
        reported = nil
    }

    /// The pump's sink: fans `kind` for `id` out to its hearers.
    /// A window no consumer hears is a stale additive delivery
    /// (`SkyLightWindowEvents.watch`'s undocumented semantics).
    func handle(_ kind: SkyLightWindowEvents.Kind, window id: WindowID) {
        let heardBy = hearers(of: id)
        guard !heardBy.isEmpty else { return }
        let action = kind.action
        if action == .follow || action == .followAndReorder {
            deliverFrame(
                id,
                to: heardBy,
                unhiding: action == .followAndReorder
            )
        }
        if action == .reorder || action == .followAndReorder {
            oweRestack(id)
        }
        if action == .hide {
            for consumer in heardBy {
                guard let hide = hooks[consumer]?.hide else { continue }
                if owedRestacks.contains(id) {
                    hiddenSinceOwed[id, default: []].insert(consumer)
                }
                hide(id)
            }
        }
    }

    /// Re-stacks `id`'s overlays in consumer order: a reorder event,
    /// and a raise that moved other windows in between `id` and its
    /// overlays and sent `id` no event of its own (#2284).
    func restack(_ id: WindowID, skipping skipped: Set<Consumer> = []) {
        for consumer in hearers(of: id) where !skipped.contains(consumer) {
            hooks[consumer]?.restack?(id)
        }
    }

    /// A later reorder or unhide re-owes every consumer.
    private func oweRestack(_ id: WindowID) {
        hiddenSinceOwed[id] = nil
        if !owedRestacks.contains(id) { owedRestacks.append(id) }
        guard !paymentScheduled else { return }
        paymentScheduled = true
        atTurnEnd { [weak self] in self?.payOwedRestacks() }
    }

    private func payOwedRestacks() {
        paymentScheduled = false
        while let id = owedRestacks.first {
            owedRestacks.removeFirst()
            let skipped = hiddenSinceOwed.removeValue(forKey: id) ?? []
            restack(id, skipping: skipped)
        }
    }

    private func hearers(of id: WindowID) -> [Consumer] {
        Consumer.allCases.filter { heard[$0]?.contains(id) == true }
    }

    /// One gated bounds read, only where a hearer takes frames.
    private func deliverFrame(
        _ id: WindowID,
        to hearers: [Consumer],
        unhiding: Bool
    ) {
        let takers = hearers.compactMap { hooks[$0]?.frame }
        guard !takers.isEmpty, !isAnimating(id),
            let frame = readWindowBounds(id)
        else { return }
        for take in takers { take(id, frame, unhiding) }
    }

    private func submit() {
        let wanted = Consumer.allCases.reduce(into: Set<WindowID>()) {
            $0.formUnion(heard[$1] ?? [])
            $0.formUnion(kept[$1] ?? [])
        }
        #if DEBUG
            if let override {
                isActive = override(wanted)
                return
            }
        #endif
        guard started else {
            isActive = false
            return
        }
        if trackingDisabled {
            isActive = false
        } else {
            // Nothing asked yet: no verdict to report, so an empty
            // first request ahead of the first ring stays silent.
            guard triedSource || !wanted.isEmpty else {
                isActive = false
                return
            }
            if !triedSource {
                triedSource = true
                source = SkyLightWindowEvents.shared
                source?.attach(self)
            }
            isActive = source?.watch(wanted) == true
        }
        if reported != isActive {
            reported = isActive
            onLog(statusMessage)
        }
    }

    /// The one line telling a QA run which path it is on — it
    /// names the lever when the lever forced the fallback.
    private var statusMessage: String {
        if isActive { return "WindowServer border tracking active" }
        if trackingDisabled {
            return "WindowServer border tracking disabled by "
                + "KIWIDESK_NO_WS_TRACKING; using AX fallback"
        }
        return "WindowServer border tracking unavailable; "
            + "using AX fallback"
    }
}
