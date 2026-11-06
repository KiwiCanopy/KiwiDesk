import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where `DesktopMoveAwayTests`' away window lands (#3034): its filing,
/// the shared-Desktop refusals and the follow, over the same fixture.
/// Split at the §2.1 ceiling.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming an away window: landing (#3034)", .serialized)
@MainActor
struct DesktopMoveAwayLandingTests {
    private let focused = WindowID(7)
    private let away = WindowID(9)
    private let pid: pid_t = 900_001
    private let mail = SpaceID("mail")
    private var id: JSONValue { .number(Double(away.raw)) }

    private func makeCore(
        spaces: [NativeSpace]? = nil,
        bridge: Bool = true
    ) -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride =
            spaces
            ?? authorityTopology(mainCurrent: 10, secondaryCurrent: 20)
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            bridge ? desktopVerbBridgeClasses[$0] : nil
        }
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: focused, pid: 900_002, appName: "Here")
            )
        )
        core.state.apply(.windowFocused(focused))
        file(core)
        return core
    }

    private func file(_ core: KiwiCore) {
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: pid,
            appName: "Away",
            appBundleID: "com.example.away",
            title: "Elsewhere",
            nativeSpace: 11
        )
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func arrive(_ core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(id: away, pid: pid, appName: "Away")
            )
        )
    }

    private func addDisplays(_ core: KiwiCore) {
        for (index, name) in ["A", "B"].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 1920,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                )
            )
        }
    }

    // MARK: - A named Space

    @Test("a named Space is filed at once and paid at the arrival")
    func namedSpace() {
        let core = makeCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = .departed("1")
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
        #expect(core.pendingSpace.isEmpty)
        arrive(core)
        #expect(core.state.workspaces.space(of: away) == mail)
    }

    /// A move ends the restored provenance, or the #1010 net would
    /// not answer the arrival and an owed frame would be paid over it.
    @Test("a restored filing becomes a watched departure")
    func restoredBecomesDeparted() {
        let core = makeCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = .restored("1")
        core.state.restoredFrames[away] = .init(
            frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            floating: false
        )
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpaces[away] == .departed("1"))
        #expect(core.state.restoredFrames[away] == nil)
    }

    @Test("a hand float's record survives, and it arrives floating")
    func handFloatStays() {
        let core = makeCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = .restored("1")
        core.state.restoredFrames[away] = .init(
            frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            floating: true
        )
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpaces[away] == .departed("1"))
        arrive(core)
        #expect(core.state.windows[away]?.isFloating == true)
    }

    /// Filed into the Space shown, it is a return and no new window,
    /// so the fold's new-window grant leaves the focus alone.
    @Test("an unfiled window arriving takes no focus")
    func unfiledTakesNoFocus() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.state.rememberedSpace(of: away) == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) != nil)
        arrive(core)
        #expect(core.focusedWindowID == focused)
    }

    /// The reveal activates that Desktop's own Space, which the Space
    /// shown now says nothing about (#1010).
    @Test("an unfiled window bound for a hidden Desktop stays unfiled")
    func unfiledHiddenStaysUnfiled() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(4), .null, id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == nil)
    }

    @Test("a window nothing has filed takes the name")
    func unfiledTakesTheName() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.state.rememberedSpace(of: away) == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
    }

    /// Separate Spaces: the parse compares with the Desktop's screen,
    /// the same refusal a tracked window takes.
    @Test("a Space off the Desktop's screen refuses")
    func offTheDesktopsScreen() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        core.state.workspaces.assign(mail, to: DisplayID(2))
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail"), id]
        )
        #expect(response.error?.contains("another screen") == true)
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    // MARK: - Shared Desktops

    private func sharedCore() -> KiwiCore {
        let core = makeCore(spaces: [
            authoritySpace(10, display: "Main", current: true),
            authoritySpace(11, display: "Main"),
            authoritySpace(12, display: "Main"),
        ])
        addDisplays(core)
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.rememberedSpaces[away] = .departed("1")
        core.state.workspaces.assign(mail, to: DisplayID(2))
        return core
    }

    /// Only an arrival files it, and an arrival stays on its screen,
    /// so a shown Desktop refuses here where a tracked window crosses.
    @Test("a Space off its screen refuses for a shown Desktop too")
    func sharedRefusesEitherTarget() {
        let core = sharedCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).error
                == "Screens can only be crossed through the visible Desktop. "
                + "Cross there first, then move the window."
        )
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).error
                == "Screens can only be crossed through the visible Desktop. "
                + "Cross there first, then move the window."
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a Space on its screen is taken")
    func sharedTakesItsScreen() {
        let core = sharedCore()
        defer { teardown() }
        core.state.workspaces.assign(mail, to: DisplayID(1))
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
    }

    /// The frame is what the arrival reads, so it outranks the
    /// remembered Space's screen.
    @Test("the window's frame decides, where memory disagrees")
    func frameOutranksMemory() throws {
        let core = sharedCore()
        defer { teardown() }
        let screen = try #require(ScreenList.all.first)
        let shown = try #require(screen.kiwiDisplayID)
        let frame = GeometryUtils.axVisibleFrame(of: screen)
        core.windowServer.readWindowBounds = { _ in frame }
        core.state.workspaces.assign("1", to: DisplayID(UInt32.max))
        core.state.workspaces.assign(mail, to: shown)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).isSuccess
        )
    }

    /// No frame and no filing: the arrival's screen is unknown, so
    /// the name could be dropped with success, #3033's symptom.
    @Test("a screen no reading can name refuses")
    func unknownScreenRefuses() {
        let core = sharedCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = nil
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).error?.contains("crossed through") == true
        )
    }

    // MARK: - The focus

    /// The fold grants the focus in state alone, so without the debt
    /// the next focused verb refuses at the #292 preflight (device,
    /// 2026-11-06).
    @Test("an arrival in a Space with no focus owes the raise")
    func vacantOwesTheRaise() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("focus_space", args: [.string("mail")]).isSuccess)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        // A filing here would undo a #1010 re-home across screens.
        #expect(core.jump.take(arrived: away)?.relocates == false)
    }

    @Test("an arrival beside a focus owes nothing")
    func occupiedOwesNothing() {
        let core = makeCore()
        defer { teardown() }
        let active = core.state.workspaces.activeSpace!
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string(active.raw), id]
            ).isSuccess
        )
        #expect(core.jump.take(arrived: away) == nil)
    }
}
