import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent("kiwi-forget-\(UUID().uuidString)")
    )
}

/// Replaces the connected screens with 100x100 ones named `names`.
@MainActor
private func connect(_ core: KiwiCore, _ names: [String]) {
    for display in core.state.workspaces.allDisplays {
        core.state.workspaces.removeDisplay(display.id)
    }
    for (index, name) in names.enumerated() {
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(UInt32(index + 1)),
                name: name,
                frame: CGRect(
                    x: CGFloat(index) * 100,
                    y: 0,
                    width: 100,
                    height: 100
                )
            )
        )
    }
}

/// One field of an object reply, nil for anything else.
private func field(_ value: JSONValue?, _ key: String) -> JSONValue? {
    guard case .object(let fields)? = value else { return nil }
    return fields[key]
}

private func fp(_ names: String...) -> [String] {
    names.map { "\($0):100x100" }.sorted()
}

/// Forgetting a stored screen setup (#3324): one exact combination
/// leaves its one holder through the claim's own strip, and the
/// connected or an unknown setup is refused as a structured error.
@Suite("Forgetting a screen setup (#3324)", .serialized)
@MainActor
struct MonitorSetForgetTests {
    /// "Desk" saved on A+B, then on A+C: two setups sharing A.
    private func twoSetups(_ core: KiwiCore) throws {
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Desk", modes: nil)
        connect(core, ["A", "C"])
        try core.persistProfile(named: "Desk", modes: nil)
    }

    @Test("only the named combination leaves; one sharing a screen stays")
    func onlyThatCombination() throws {
        let core = makeCore()
        try twoSetups(core)
        let holders = try core.forgetMonitorSet(fp("B", "A"))
        #expect(holders == ["Desk"])
        let desk = try core.profiles.read(name: "Desk")
        #expect(desk.monitorSets.map(\.monitors) == [fp("A", "C")])
    }

    @Test("the connected setup is refused, and nothing is written")
    func connectedRefused() throws {
        let core = makeCore()
        try twoSetups(core)
        #expect(throws: MonitorSetForgetError.connected) {
            try core.forgetMonitorSet(fp("A", "C"))
        }
        #expect(try core.profiles.read(name: "Desk").monitorSets.count == 2)
        let reply = core.execute(
            "forget_monitor_set",
            args: fp("A", "C").map { .string($0) }
        )
        #expect(!reply.isSuccess)
        #expect(field(reply.data, "reason") == .string("connected_setup"))
    }

    @Test("an unknown setup is refused with its own code")
    func unknownRefused() throws {
        let core = makeCore()
        try twoSetups(core)
        let reply = core.execute(
            "forget_monitor_set",
            args: fp("A", "Z").map { .string($0) }
        )
        #expect(!reply.isSuccess)
        #expect(field(reply.data, "reason") == .string("unknown_setup"))
        #expect(!core.execute("forget_monitor_set", args: []).isSuccess)
    }

    @Test("a default left dormant loses its flag, and nobody takes it")
    func dormantDefaultClears() throws {
        let core = makeCore()
        connect(core, ["A"])
        try core.persistProfile(named: "Home", modes: nil)
        try core.profiles.setDefault(name: "Home")
        connect(core, ["B"])
        try core.persistProfile(named: "Other", modes: nil)
        try core.forgetMonitorSet(fp("A"))
        let home = try core.profiles.read(name: "Home")
        #expect(home.isDormant)
        #expect(!home.isDefault)
        #expect(home.monitorCount == 1)
        #expect(try !core.profiles.read(name: "Other").isDefault)
    }

    @Test("an open draft hears which setup left which profile")
    func draftIsTold() throws {
        let core = makeCore()
        try twoSetups(core)
        var heard: [(String, CapturedWrite)] = []
        core.profiles.onCapturedLive = { heard.append(($0, $1)) }
        // Unsorted on purpose: the payload carries the canonical set.
        try core.forgetMonitorSet(["B:100x100", "A:100x100"])
        #expect(heard.count == 1)
        #expect(heard.first?.0 == "Desk")
        #expect(heard.first?.1 == .forgottenSetup(monitors: fp("A", "B")))
    }

    @Test("list_monitor_sets names each setup, connected first")
    func listShape() throws {
        let core = makeCore()
        try twoSetups(core)
        let known = core.knownMonitorSets()
        #expect(known.map(\.monitors) == [fp("A", "C"), fp("A", "B")])
        #expect(known.map(\.isConnected) == [true, false])
        #expect(
            known.allSatisfy { $0.profile == "Desk" && !$0.isProfilesLast }
        )
        let reply = core.execute("list_monitor_sets")
        guard case .array(let rows)? = reply.data else {
            Issue.record("no rows")
            return
        }
        #expect(rows.count == 2)
        #expect(field(rows.first, "connected") == .bool(true))
        #expect(field(rows.first, "profile") == .string("Desk"))
    }

    @Test("the list runs connected, then by screen count, then by name")
    func listOrder() {
        func set(
            _ names: [String],
            _ profile: String = "P",
            connected: Bool = false
        ) -> KnownMonitorSet {
            KnownMonitorSet(
                monitors: names.map { "\($0):100x100" }.sorted(),
                profile: profile,
                isConnected: connected,
                isProfilesLast: false
            )
        }
        let stored = [
            set(["Zeta", "Alpha"], "A"),
            set(["beta"], "Z"),
            set(["Dell", "Built-in"], connected: true),
            set(["Alpha", "Beta", "Gamma"]),
            set(["Alpha"], "Z"),
            set(["Alpha", "Dell"], "A"),
            set(["Gamma"], "A"),
        ]
        let sorted = stored.sorted(
            by: KnownMonitorSet.listOrder(in: Locale(identifier: "en"))
        )
        let names = sorted.map {
            $0.monitors.map { Display.fingerprintParts($0).name }
        }
        #expect(
            names
                == [
                    ["Built-in", "Dell"],
                    ["Alpha"], ["beta"], ["Gamma"],
                    ["Alpha", "Dell"], ["Alpha", "Zeta"],
                    ["Alpha", "Beta", "Gamma"],
                ]
        )
        #expect(sorted.map(\.listGroup) == [0, 1, 1, 1, 2, 2, 3])
    }

    @Test("a same-named pair reads in size order, whoever holds it")
    func sameNameBySize() {
        func set(_ size: String, _ profile: String) -> KnownMonitorSet {
            KnownMonitorSet(
                monitors: ["BenQ:\(size)"],
                profile: profile,
                isConnected: false,
                isProfilesLast: false
            )
        }
        let sorted = [set("1920x1080", "A"), set("800x600", "Z")]
            .sorted(
                by: KnownMonitorSet.listOrder(in: Locale(identifier: "en"))
            )
        #expect(
            sorted.map(\.monitors) == [["BenQ:800x600"], ["BenQ:1920x1080"]]
        )
    }

    @Test("names compare numerically, and the holder settles a tie")
    func numericThenHolder() {
        func set(_ name: String, _ profile: String) -> KnownMonitorSet {
            KnownMonitorSet(
                monitors: ["\(name):100x100"],
                profile: profile,
                isConnected: false,
                isProfilesLast: false
            )
        }
        let sorted = [
            set("Dell 10", "A"), set("Alpha", "Z"), set("Dell 2", "A"),
            set("Alpha", "A"),
        ]
        .sorted(by: KnownMonitorSet.listOrder(in: Locale(identifier: "en")))
        #expect(
            sorted.map { "\($0.monitors[0]) \($0.profile)" } == [
                "Alpha:100x100 A", "Alpha:100x100 Z",
                "Dell 2:100x100 A", "Dell 10:100x100 A",
            ]
        )
    }

    @Test("names collate in the locale handed in")
    func collatesInTheLocale() {
        func set(_ name: String) -> KnownMonitorSet {
            KnownMonitorSet(
                monitors: ["\(name):100x100"],
                profile: "P",
                isConnected: false,
                isProfilesLast: false
            )
        }
        func order(_ locale: String) -> [String] {
            [set("Zeta"), set("Öra")]
                .sorted(
                    by: KnownMonitorSet.listOrder(
                        in: Locale(identifier: locale)
                    )
                )
                .map { Display.fingerprintParts($0.monitors[0]).name }
        }
        #expect(order("en") == ["Öra", "Zeta"])
        #expect(order("sv") == ["Zeta", "Öra"])
    }

    @Test("list_monitor_sets answers in the card's order")
    func replyKeepsTheOrder() throws {
        let core = makeCore()
        connect(core, ["A", "B", "C"])
        try core.persistProfile(named: "Wide", modes: nil)
        connect(core, ["B"])
        try core.persistProfile(named: "Solo", modes: nil)
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Desk", modes: nil)
        connect(core, ["A"])
        try core.persistProfile(named: "Lap", modes: nil)
        let reply = core.execute("list_monitor_sets")
        guard case .array(let rows)? = reply.data else {
            Issue.record("no rows")
            return
        }
        #expect(
            rows.map { field($0, "profile") }
                == ["Lap", "Solo", "Desk", "Wide"].map { .string($0) }
        )
    }
}
