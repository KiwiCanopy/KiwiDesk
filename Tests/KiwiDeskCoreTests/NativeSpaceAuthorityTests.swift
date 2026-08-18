import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// #888 main-display authority: "Desktop N activates" means the
// MAIN display's current Desktop became N. One serialized suite
// file — every test drives the process-global DEBUG overrides
// (`spacesOverride`, `mainDisplayUUIDOverride`,
// `hasSeparateSpacesOverride`, …), and a second suite would race
// it under parallel testing.

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-core-\(UUID().uuidString)"
            )
    )
}

@MainActor
private func connect(_ core: KiwiCore, _ displays: [Display]) {
    for display in displays {
        core.state.workspaces.upsertDisplay(display)
    }
}

private func display(
    _ id: UInt32,
    _ name: String,
    x: CGFloat = 0
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 100, height: 100)
    )
}

private func space(
    _ id: UInt64,
    display: String,
    current: Bool = false,
    isUser: Bool = true
) -> NativeSpace {
    NativeSpace(
        id: id,
        displayUUID: display,
        isCurrent: current,
        isUser: isUser
    )
}

/// Two displays, two Desktops each: A carries Desktops 1–2
/// (spaces 10, 11), B carries Desktops 3–4 (spaces 20, 21).
private func topology(
    mainCurrent: UInt64,
    secondaryCurrent: UInt64
) -> [NativeSpace] {
    [
        space(10, display: "UUID-A", current: mainCurrent == 10),
        space(11, display: "UUID-A", current: mainCurrent == 11),
        space(20, display: "UUID-B", current: secondaryCurrent == 20),
        space(21, display: "UUID-B", current: secondaryCurrent == 21),
    ]
}

/// Clears every override a test here may have set.
@MainActor
private func resetOverrides() {
    NativeSpaces.activeDesktopNumberOverride = nil
    NativeSpaces.activeSpaceIDOverride = nil
    NativeSpaces.spacesOverride = nil
    NativeSpaces.mainDisplayUUIDOverride = nil
    NativeSpaces.displayUUIDOverride = nil
    DisplaySpacesSetting.hasSeparateSpacesOverride = nil
    PositionalDisplays.liveMainIDOverride = nil
}

@Suite("Main-display Desktop authority (#888)", .serialized)
@MainActor
struct DesktopAuthorityTests {
    @Test("The active Desktop is the main display's current one")
    func mainAnswers() {
        defer { resetOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        #expect(NativeSpaces.activeDesktopNumber() == 1)
        // A secondary display's swipe moves the answer nowhere.
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        #expect(NativeSpaces.activeDesktopNumber() == 1)
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 11,
            secondaryCurrent: 21
        )
        #expect(NativeSpaces.activeDesktopNumber() == 2)
    }

    @Test("An unresolvable main display falls back to the global read")
    func fallsBack() {
        defer { resetOverrides() }
        // Main UUID absent from the snapshot (shared mode's
        // synthetic managed display, an unplugged screen): the
        // global active space answers.
        NativeSpaces.mainDisplayUUIDOverride = "UUID-X"
        NativeSpaces.activeSpaceIDOverride = 20
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        #expect(NativeSpaces.activeDesktopNumber() == 3)
    }

    @Test("A fullscreen Desktop on the main display is nil")
    func fullscreenIsNil() {
        defer { resetOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [
            space(10, display: "UUID-A"),
            space(99, display: "UUID-A", current: true, isUser: false),
            space(20, display: "UUID-B", current: true),
        ]
        #expect(NativeSpaces.activeDesktopNumber() == nil)
    }
}

@Suite("Secondary-display switches (#888)", .serialized)
@MainActor
struct SecondarySwitchTests {
    /// A separate-Spaces, two-display core on Desktop 1 with
    /// "Bound" bound to Desktop 1 and "Loaded" manually active —
    /// the state in which a binding re-apply is observable.
    private func makeSeparateCore() -> KiwiCore {
        let core = makeCore()
        connect(core, [display(1, "A"), display(2, "B", x: 100)])
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        DisplaySpacesSetting.hasSeparateSpacesOverride = true
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        core.execute("save_profile", args: [.string("Bound")])
        core.execute("save_profile", args: [.string("Loaded")])
        core.execute(
            "bind_profile_to_native_space",
            args: [.number(1), .string("Bound")]
        )
        core.execute("load_profile", args: [.string("Loaded")])
        core.lastNativeSpace = 1
        return core
    }

    @Test("A secondary swipe never selects a profile")
    func secondaryNeverSelects() {
        defer { resetOverrides() }
        let core = makeSeparateCore()
        #expect(core.profiles.currentName == "Loaded")
        // B swipes 20 → 21; the main display stays on Desktop 1.
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        core.handleNativeSpaceChange()
        // Without the #888 arm, applyNativeSpaceBinding would
        // snap the manually-loaded profile back to "Bound".
        #expect(core.profiles.currentName == "Loaded")
        #expect(core.desktopMemory.virtualSpaces.isEmpty)
    }

    @Test("A main-display switch still applies the binding")
    func mainStillApplies() {
        defer { resetOverrides() }
        let core = makeSeparateCore()
        core.execute(
            "bind_profile_to_native_space",
            args: [.number(2), .string("Bound")]
        )
        // Main swipes Desktop 1 → 2.
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.handleNativeSpaceChange()
        #expect(core.profiles.currentName == "Bound")
        // And the outgoing Desktop remembered its Space, keyed
        // under the main display.
        #expect(
            core.desktopMemory.virtualSpaces["UUID-A"]?[1]
                != nil
        )
    }
}

@Suite("Per-Desktop Space memory (#888)", .serialized)
@MainActor
struct DesktopMemoryTests {
    @Test("A remembered Space foreign to the space set falls back")
    func staleFallsBack() {
        defer { resetOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces["UUID-A"] = [
            3: SpaceID(9)
        ]
        // Space "9" is no profile's — the binding apply that
        // precedes this read may have swapped the space set —
        // so stale takes the same exit as missing.
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(1)
        )
    }

    @Test("Memory keyed to another display is not read")
    func perDisplayKeying() {
        defer { resetOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.desktopMemory.virtualSpaces["UUID-B"] = [
            3: SpaceID(2)
        ]
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(1)
        )
    }

    @Test("The keying does not depend on the separate-Spaces mode")
    func modeIndifferent() {
        defer { resetOverrides() }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // Written under shared mode…
        DisplaySpacesSetting.hasSeparateSpacesOverride = false
        core.rememberVirtualSpace(SpaceID(2), leaving: 3)
        // …reads back identically under separate Spaces (and
        // vice versa): the key is (display, number) in both, so
        // the login-time mode flip needs no migration.
        DisplaySpacesSetting.hasSeparateSpacesOverride = true
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(2)
        )
        DisplaySpacesSetting.hasSeparateSpacesOverride = false
        #expect(
            core.virtualSpaceTarget(for: 3) == SpaceID(2)
        )
    }
}

@Suite("native_space_change display dimension (#888)", .serialized)
@MainActor
struct NativeSpaceEventTests {
    private func makeEventCore() -> (
        core: KiwiCore, events: () -> [(KiwiNotification, JSONValue)]
    ) {
        let core = makeCore()
        connect(core, [display(1, "A"), display(2, "B", x: 100)])
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        PositionalDisplays.liveMainIDOverride = DisplayID(1)
        NativeSpaces.displayUUIDOverride = { id in
            id == DisplayID(1) ? "UUID-A" : "UUID-B"
        }
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        return (core, { events })
    }

    private func data(
        in events: [(KiwiNotification, JSONValue)]
    ) -> [String: JSONValue]? {
        guard
            let (_, data) = events.last(where: {
                $0.0 == .nativeSpaceChange
            }),
            case .object(let payload) = data
        else { return nil }
        return payload
    }

    @Test("A secondary switch names its monitor and Desktop")
    func secondaryDimension() {
        defer { resetOverrides() }
        let (core, events) = makeEventCore()
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        core.emitNativeSpaceChange()
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(2))
        #expect(payload?["native_space"] == .number(4))
    }

    @Test("A main switch is monitor 1")
    func mainDimension() {
        defer { resetOverrides() }
        let (core, events) = makeEventCore()
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.emitNativeSpaceChange()
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(1))
        #expect(payload?["native_space"] == .number(2))
    }

    @Test("A repeated notification reports the main display")
    func repeatedNotification() {
        defer { resetOverrides() }
        let (core, events) = makeEventCore()
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        NativeSpaces.spacesOverride = topology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        core.emitNativeSpaceChange()
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(1))
        #expect(payload?["native_space"] == .number(1))
    }
}
