import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.profileVerdict` — what loads right now, and by which
/// rule (#678 turn 13a).
///
/// The GUI's "Which profile loads" card reads this. Its first cut
/// asked `ProfileManager.match` alone and so answered only the
/// display half of the rule: with a Desktop bound it named the
/// profile a MONITOR change would load while a different one was
/// on screen. These pin the precedence, not just the cases —
/// `KiwiCore+MonitorChange` states it as "a native-Space binding
/// wins over matching (#7)", and a verdict that ranks them the
/// other way is wrong in exactly the configuration the bindings
/// card below it creates.
@Suite("Profile verdict")
@MainActor
struct ProfileVerdictTests {
    private func core() -> KiwiCore {
        let core = makeTestCore()
        // One pinned display, so the verdict reasons from a
        // fixture rather than from whatever this machine has
        // plugged in (#531, tests.md).
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Studio",
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 2560,
                    height: 1440
                )
            )
        )
        return core
    }

    private func profile(
        _ name: String,
        monitors: [String],
        isDefault: Bool = false
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: monitors)],
            isDefault: isDefault,
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
    }

    /// The live display's own fingerprint, so an "exact" fixture
    /// is exact by construction rather than by a literal that
    /// silently stops matching if `Display.fingerprint` changes
    /// shape.
    private func liveFingerprints(_ core: KiwiCore) -> [String] {
        core.state.workspaces.allDisplays.map(\.fingerprint)
    }

    @Test("an exact monitor set wins over the count default")
    func exactBeatsDefault() throws {
        let core = core()
        let live = liveFingerprints(core)
        try core.profiles.save(profile("Desk", monitors: live))
        try core.profiles.save(
            profile("Other", monitors: ["Absent:1x1"], isDefault: true)
        )
        #expect(
            core.profileVerdict(activeDesktop: nil)
                == .exactMonitors(name: "Desk")
        )
    }

    @Test("the count default answers when no set matches")
    func countDefault() throws {
        let core = core()
        try core.profiles.save(
            profile(
                "Fallback",
                monitors: ["Absent:1x1"],
                isDefault: true
            )
        )
        #expect(
            core.profileVerdict(activeDesktop: nil)
                == .countDefault(name: "Fallback")
        )
    }

    /// No saved profile at all: the count's Standard composes,
    /// and the verdict carries its STABLE English name (the GUI
    /// localizes it).
    @Test("a built-in Standard answers when nothing matches")
    func builtInStandard() {
        #expect(
            core().profileVerdict(activeDesktop: nil)
                == .builtInStandard(name: "Developer")
        )
    }

    /// The precedence itself. The bound profile is deliberately
    /// NOT the one an exact match would pick, so a verdict that
    /// consulted `match` first would name the other one and this
    /// reds.
    @Test("a Desktop binding outranks an exact monitor match")
    func bindingBeatsExactMatch() throws {
        let core = core()
        let live = liveFingerprints(core)
        try core.profiles.save(profile("Desk", monitors: live))
        try core.profiles.save(
            profile("Bound", monitors: ["Absent:1x1"])
        )
        core.nativeSpaceBindings = [2: "Bound"]
        #expect(
            core.profileVerdict(activeDesktop: 2)
                == .boundToDesktop(name: "Bound", desktop: 2)
        )
    }

    /// A binding on ANOTHER Desktop does not claim this one.
    @Test("only the active Desktop's binding applies")
    func bindingIsPerDesktop() throws {
        let core = core()
        let live = liveFingerprints(core)
        try core.profiles.save(profile("Desk", monitors: live))
        try core.profiles.save(
            profile("Bound", monitors: ["Absent:1x1"])
        )
        core.nativeSpaceBindings = [2: "Bound"]
        #expect(
            core.profileVerdict(activeDesktop: 1)
                == .exactMonitors(name: "Desk")
        )
    }

    /// A binding naming a profile that cannot be read falls
    /// THROUGH to matching — the same fall-through the live path
    /// takes on a load failure. A verdict that named the
    /// unreadable profile would promise a load that fails.
    @Test("a dangling binding falls through to matching")
    func danglingBindingFallsThrough() throws {
        let core = core()
        let live = liveFingerprints(core)
        try core.profiles.save(profile("Desk", monitors: live))
        core.nativeSpaceBindings = [2: "Deleted"]
        #expect(
            core.profileVerdict(activeDesktop: 2)
                == .exactMonitors(name: "Desk")
        )
    }
}
