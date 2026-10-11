import Foundation
import Testing

@testable import KiwiDeskCore

/// `DesktopMemory`'s window-keyed stores are hand-mirrored across
/// three lifecycle doors — the #634 forget, a window gone for good,
/// a native-tab re-key — and a store a door forgets is a debt to a
/// dead id. The roster is REFLECTED (`parity-tests.md`): a new
/// stored property naming `WindowID` reds here until it joins the
/// register, and every registered store is seeded and put through
/// each door.
@Suite("Desktop memory store parity")
@MainActor
struct DesktopMemoryStoreParityTests {
    /// Every stored property whose type names `WindowID`, closures
    /// (the compositor seams) aside.
    private static let register: Set<String> = [
        "honoredFocus", "lastHonoredOn", "stickyLeft", "stickyReturn",
        "switchDepartures",
    ]

    private let old = WindowID(7)
    private let new = WindowID(8)

    @Test("every window-keyed store is in the register")
    func registerIsTheReflectedRoster() {
        let memory = DesktopMemory()
        var roster: Set<String> = []
        for child in Mirror(reflecting: memory).children {
            guard let label = child.label else { continue }
            let type = String(describing: type(of: child.value))
            guard type.contains("WindowID"), !type.contains("->")
            else { continue }
            roster.insert(label)
        }
        #expect(roster == Self.register)
    }

    /// Every registered store, and the return debt, naming `old`.
    private func seeded() -> KiwiCore {
        let core = makeTestCore()
        let memory = core.desktopMemory
        memory.honoredFocus = [SpaceID("1"): [10: old]]
        memory.lastHonoredOn = [10: old]
        memory.stickyLeft = [10: old]
        memory.stickyReturn = (old, .now)
        memory.switchDepartures = [old: Date()]
        memory.returnFocus.record(old)
        return core
    }

    private func names(_ id: WindowID, in memory: DesktopMemory) -> [String] {
        var found: [String] = []
        if memory.honoredFocus.values.contains(where: {
            $0.values.contains(id)
        }) {
            found.append("honoredFocus")
        }
        if memory.lastHonoredOn.values.contains(id) {
            found.append("lastHonoredOn")
        }
        if memory.stickyLeft.values.contains(id) { found.append("stickyLeft") }
        if memory.stickyReturn?.window == id { found.append("stickyReturn") }
        if memory.switchDepartures[id] != nil {
            found.append("switchDepartures")
        }
        if memory.returnFocus.owed() == id { found.append("returnFocus") }
        return found
    }

    @Test("the reset forgets every store")
    func forgetReachesEveryStore() {
        let core = seeded()
        core.forgetDesktopFocus()
        #expect(names(old, in: core.desktopMemory).isEmpty)
    }

    @Test("a window gone for good leaves every store")
    func retireReachesEveryStore() {
        let core = seeded()
        core.retireAwayDebts(of: old)
        #expect(names(old, in: core.desktopMemory).isEmpty)
    }

    @Test("a native-tab re-key follows in every store")
    func rekeyReachesEveryStore() {
        let core = seeded()
        core.rekeyDesktopFocus(old: old, new: new)
        let memory = core.desktopMemory
        #expect(names(old, in: memory).isEmpty)
        #expect(
            Set(names(new, in: memory))
                == Self.register.union(["returnFocus"])
        )
    }
}
