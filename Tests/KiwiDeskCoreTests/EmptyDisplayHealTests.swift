import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The empty-display heal (#1175): a connected screen the total
/// resolve leaves with no space gets one seeded — a fresh
/// number, the starter setup's lead layout for that screen,
/// pinned to the monitor — at the one resolve every door ends in.
/// One fixture per door: the Lua pin that moves a screen's last
/// space away, and the dirty profile whose spaces all belong to
/// the other screen. Named spaces on purpose: the count's
/// Standard plans numbered spaces across screens, so a numbered
/// one-screen profile would be spread rather than healed.
@Suite("Empty-display heal (#1175)", .serialized)
@MainActor
struct EmptyDisplayHealTests {
    private static let displayA = Display(
        id: DisplayID(1),
        name: "A",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
    private static let displayB = Display(
        id: DisplayID(2),
        name: "B",
        frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    )

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-heal-\(UUID().uuidString)"
                )
        )
    }

    /// Two screens, `work` pinned to A and `mail` to B, beside
    /// the core's own default space `1` on A — so the seed the
    /// heal mints is `2`.
    private func twoScreenCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(Self.displayA)
        core.state.workspaces.upsertDisplay(Self.displayB)
        core.state.workspaces.ensureSpace("work")
        core.state.workspaces.ensureSpace("mail")
        core.spacePins["work"] = Self.displayA.fingerprint
        core.spacePins["mail"] = Self.displayB.fingerprint
        core.resolveSpaceDisplays(mainID: Self.displayA.id)
        return core
    }

    private func spaces(
        _ core: KiwiCore,
        on display: Display
    ) -> [SpaceID] {
        core.state.workspaces.spaces(on: display.id)
    }

    /// The layout the starter setup opens B in, read off the one
    /// walk rather than spelled (#1018).
    private func leadOfB() -> LayoutMode? {
        StarterAllocation.modes(
            sizes: StarterSetup.sizes(
                displays: [Self.displayA, Self.displayB],
                mainID: Self.displayA.id
            )
        )[1].first
    }

    @Test("A screen every space is pinned away from gets a seed")
    func pinDoorSeeds() {
        let core = twoScreenCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(spaces(core, on: Self.displayB) == ["mail"])
        core.execute(
            "pin_space_to_display",
            args: [.string("mail"), .string("A")]
        )
        #expect(
            spaces(core, on: Self.displayA) == ["1", "work", "mail"]
        )
        #expect(spaces(core, on: Self.displayB) == ["2"])
        #expect(core.spacePins["2"] == Self.displayB.fingerprint)
        #expect(core.state.workspaces["2"]?.mode == leadOfB())
        #expect(log.contains { $0.hasPrefix("heal: display 'B'") })
    }

    @Test("A screen that keeps a space is left alone")
    func fullScreensSeedNothing() {
        let core = twoScreenCore()
        let before = core.state.workspaces.allSpaces.map(\.id)
        core.resolveSpaceDisplays(mainID: Self.displayA.id)
        #expect(core.state.workspaces.allSpaces.map(\.id) == before)
        #expect(core.healedSpaces.isEmpty)
    }

    @Test("A second resolve seeds nothing more")
    func healIsIdempotent() {
        let core = twoScreenCore()
        core.execute(
            "pin_space_to_display",
            args: [.string("mail"), .string("A")]
        )
        let once = core.state.workspaces.allSpaces.map(\.id)
        core.resolveSpaceDisplays(mainID: Self.displayA.id)
        #expect(core.state.workspaces.allSpaces.map(\.id) == once)
        #expect(spaces(core, on: Self.displayB) == ["2"])
    }

    @Test("Deleting a screen's last space heals it back")
    func deleteDoorSeeds() {
        let core = twoScreenCore()
        core.execute("delete_space", args: [.string("mail")])
        #expect(core.state.workspaces["mail"] == nil)
        #expect(spaces(core, on: Self.displayB) == ["2"])
    }

    /// One screen, `work` pinned to A, saved as `Solo`; then B
    /// connects.
    private func soloCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(Self.displayA)
        core.state.workspaces.ensureSpace("work")
        core.spacePins["work"] = Self.displayA.fingerprint
        core.resolveSpaceDisplays(mainID: Self.displayA.id)
        core.execute("save_profile", args: [.string("Solo")])
        core.state.workspaces.upsertDisplay(Self.displayB)
        return core
    }

    @Test("A one-screen profile loaded on two screens seeds the second")
    func profileDoorSeeds() {
        let core = soloCore()
        core.execute("load_profile", args: [.string("Solo")])
        #expect(spaces(core, on: Self.displayA) == ["1", "work"])
        #expect(spaces(core, on: Self.displayB) == ["2"])
        #expect(core.spacePins["2"] == Self.displayB.fingerprint)
        // An explicit reload prunes what the profile does not
        // declare — its own contract — and the heal seeds B
        // again rather than leaving it empty.
        core.execute("load_profile", args: [.string("Solo")])
        #expect(
            core.state.workspaces.allSpaces.map(\.id)
                == ["1", "work", "2"]
        )
        #expect(spaces(core, on: Self.displayB) == ["2"])
    }

    @Test("An un-pruned re-apply re-pins the same seed, windows kept")
    func reapplyReusesTheSeed() throws {
        // The binding and monitor-change doors re-apply without
        // pruning, and reset the pins: the ledger hands the heal
        // its earlier seed back instead of a second one.
        let core = soloCore()
        core.execute("load_profile", args: [.string("Solo")])
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 7, appName: "App")
            )
        )
        core.state.workspaces.add(WindowID(7), to: "2")
        let solo = try core.profiles.read(name: "Solo")
        core.apply(profile: solo, forceRetile: false)
        #expect(
            core.state.workspaces.allSpaces.map(\.id)
                == ["1", "work", "2"]
        )
        #expect(spaces(core, on: Self.displayB) == ["2"])
        #expect(core.spacePins["2"] == Self.displayB.fingerprint)
        #expect(core.state.workspaces.space(of: WindowID(7)) == "2")
    }
}
