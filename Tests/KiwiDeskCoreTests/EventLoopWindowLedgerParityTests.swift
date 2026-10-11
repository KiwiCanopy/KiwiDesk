import AppKit
import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// `EventLoop`'s window-keyed stores are hand-mirrored across three
/// doors — `releaseWindowRegistration`, the native-tab re-key
/// (`applyTabRekey`, #308) and `stop()` — and a store a door forgets
/// is a debt to a dead id. The roster is REFLECTED
/// (`parity-tests.md`): a stored property whose type names
/// `WindowID` reds here until it joins `register`, every registered
/// store is seeded with `old` and put through each door, and a door
/// leaves a store alone only where `exempt` says why.
///
/// Limitation, per the parity rule: the roster reads the property's
/// TYPE NAME, so a store wrapped in a struct of its own (`offMain`,
/// `focusOrder`, `bootScan`, `processIdentity`, `shadows`,
/// `axReads`) is invisible here — its type owns its own lifecycle
/// and its own suite. Closures (the machine seams) are skipped.
@MainActor
@Suite("Event loop window ledger parity")
struct EventLoopWindowLedgerParityTests {
    private enum Door: Hashable {
        /// `releaseWindowRegistration` must drop the id.
        case release
        /// The re-key must drop the vanished id.
        case rekeyDrops
        /// The re-key must hand the new id the vanished id's value.
        case rekeyCarries
        /// `stop()` must empty the store.
        case stop
    }

    /// Every stored property whose type names `WindowID`.
    private static let register: Set<String> = [
        "elements", "detectedFloating", "detectedFullscreen",
        "detectedSubroles",
        "ignorePending", "trackedFrames", "tabCarriers",
        "removalDistrusted", "healQuiet", "transientRetried",
        "eagerDepartureInFlight",
    ]

    private static let neverTracked =
        "holds ids that never tracked, so no tracked window's "
        + "release or re-key names them; it clears with its app "
        + "at detach"
    private static let latch =
        "a latch held for the one synchronous span of "
        + "`departEagerly`, which clears it itself"

    /// Store → why a door leaves it alone. Everything else is
    /// owed the door.
    private static let exempt: [Door: [String: String]] = [
        .release: [
            "healQuiet": neverTracked,
            "transientRetried": neverTracked,
            "eagerDepartureInFlight": latch,
        ],
        .rekeyDrops: [
            "healQuiet": neverTracked,
            "transientRetried": neverTracked,
            "eagerDepartureInFlight": latch,
        ],
        .rekeyCarries: [
            "healQuiet": neverTracked,
            "transientRetried": neverTracked,
            "eagerDepartureInFlight": latch,
            "elements": "the new id registers its own tab's element",
            "trackedFrames": "re-read from the new tab's element",
            "tabCarriers":
                "re-derived from the new tab: at the 2→1 boundary "
                + "the survivor may expose no tab group",
            "ignorePending":
                "a layer reading of the vanished window; the new "
                + "one starts unread",
            "removalDistrusted":
                "an episode about the vanished id's missing read; "
                + "the new id is listed",
        ],
        .stop: ["eagerDepartureInFlight": latch],
    ]

    private let pid: pid_t = 909_920
    private let old = WindowID(90_017)
    private let new = WindowID(90_018)

    private var element: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// The `WindowID`-naming stored properties, by label.
    private func roster(_ loop: EventLoop) -> [String: Any] {
        var found: [String: Any] = [:]
        for child in Mirror(reflecting: loop).children {
            guard let label = child.label else { continue }
            let type = String(describing: type(of: child.value))
            guard type.contains("WindowID"), !type.contains("->")
            else { continue }
            found[label] = child.value
        }
        return found
    }

    /// A loop whose every registered store names `old` — a frame
    /// of `.zero` and a tab carrier, so the re-key pairs it with a
    /// new tab whose (unanswered) AX frame reads `.zero` too.
    private func seeded() -> EventLoop {
        let loop = EventLoop()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.writeEnhancedUI = { _, _ in }
        loop.onScreenNormalWindowIDs = { [:] }
        loop.elements[pid] = [old: element]
        loop.detectedFloating[old] = .floats(.fixedSize)
        loop.detectedFullscreen[old] = true
        loop.detectedSubroles[old] = "AXUnknown"
        loop.ignorePending.insert(old)
        loop.trackedFrames[old] = .zero
        loop.tabCarriers.insert(old)
        loop.removalDistrusted[old] = RemovalEpisode(arms: 1)
        loop.healQuiet[pid] = [old]
        loop.transientRetried[pid] = [old]
        loop.eagerDepartureInFlight = old
        return loop
    }

    /// Whether `value` names `id` anywhere inside it.
    private func holds(_ value: Any, _ id: WindowID) -> Bool {
        if let found = value as? WindowID { return found == id }
        return Mirror(reflecting: value).children.contains {
            holds($0.value, id)
        }
    }

    /// The rendered value a dictionary inside `value` keys by `id`.
    private func entry(_ value: Any, _ id: WindowID) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .dictionary {
            for child in mirror.children {
                let pair = Array(Mirror(reflecting: child.value).children)
                if pair.count == 2, pair[0].value as? WindowID == id {
                    return String(describing: pair[1].value)
                }
            }
        }
        for child in mirror.children {
            if let found = entry(child.value, id) { return found }
        }
        return nil
    }

    /// The registered stores a door is owed on.
    private func owed(_ door: Door) -> Set<String> {
        Self.register.subtracting(Self.exempt[door, default: [:]].keys)
    }

    @Test("every window-keyed store is in the register")
    func registerIsTheReflectedRoster() {
        #expect(Set(roster(EventLoop()).keys) == Self.register)
        for (door, stores) in Self.exempt {
            #expect(
                Set(stores.keys).isSubset(of: Self.register),
                "\(door) exempts an unregistered store"
            )
        }
    }

    @Test("the fixture seeds every registered store")
    func fixtureSeedsEveryStore() {
        let stores = roster(seeded())
        for name in Self.register {
            #expect(
                stores[name].map { holds($0, old) } == true,
                "\(name) is not seeded"
            )
        }
    }

    @Test("releasing a window leaves no store naming it")
    func releaseReachesEveryStore() {
        let loop = seeded()
        loop.releaseWindowRegistration(old, pid: pid)
        let stores = roster(loop)
        for name in owed(.release) {
            #expect(
                stores[name].map { holds($0, old) } == false,
                "release leaves \(name) naming the window"
            )
        }
    }

    @Test("a native-tab re-key moves every store to the new id")
    func rekeyReachesEveryStore() {
        let loop = seeded()
        let before = roster(loop)
        var rekeyed: [(WindowID, WindowID)] = []
        loop.onEvent = { event in
            if case .windowRekeyed(let from, let to) = event {
                rekeyed.append((from, to))
            }
        }
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: AppRef(bundleID: "test.kiwi.ledger", name: "Ledger"),
            appeared: [(element: element, id: new)],
            live: [new],
            minimized: [],
            coalesceTabs: true
        )
        #expect(rekeyed.count == 1)
        #expect(rekeyed.first?.0 == old && rekeyed.first?.1 == new)
        let after = roster(loop)
        for name in owed(.rekeyDrops) {
            #expect(
                after[name].map { holds($0, old) } == false,
                "the re-key leaves \(name) naming the vanished id"
            )
        }
        for name in owed(.rekeyCarries) {
            let was = before[name].flatMap { entry($0, old) }
            #expect(was != nil, "\(name) has no seeded entry")
            #expect(
                after[name].flatMap { entry($0, new) } == was,
                "the re-key does not carry \(name)"
            )
        }
    }

    @Test("stopping empties every store")
    func stopReachesEveryStore() {
        let loop = seeded()
        loop.isRunning = true
        loop.stop()
        let stores = roster(loop)
        for name in owed(.stop) {
            #expect(
                stores[name].map {
                    Mirror(reflecting: $0).children.isEmpty
                } == true,
                "stop leaves \(name) populated"
            )
        }
    }
}
