import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout-cycle plate's press (#2144): `cycle_mode` pays a
/// cue naming the Space's screen, the cycle list and the layout
/// it landed on, stands down where the shelf does (#1787), and
/// the app-wide switch turns it off. An extension of this suite,
/// not a second one: every case holds the process-global
/// `currentSpaceIsUserOverride` (see the suite's header).
extension FullscreenStandDownTests {
    private final class CueBox { var cues: [ModeCycleCue] = [] }

    private func makeCueCore(isUser: Bool) -> (KiwiCore, CueBox) {
        NativeSpaces.currentSpaceIsUserOverride = { _ in isUser }
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.activate("1")
        core.state.workspaces.setMode("1", .bsp)
        core.modeCycle = [.bsp, .stack, .floating]
        core.frontWindowFrames = { [] }
        let box = CueBox()
        core.onModeCue = { box.cues.append($0) }
        return (core, box)
    }

    @Test("a cycle_mode press names the screen, list and layout")
    func cyclePressPaysTheCue() {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box) = makeCueCore(isUser: true)
        #expect(core.execute("cycle_mode", args: []).isSuccess)
        #expect(
            box.cues == [
                ModeCycleCue(
                    display: DisplayID(1),
                    cycle: [.bsp, .stack, .floating],
                    current: .stack
                )
            ]
        )
    }

    @Test("a full-screen Space keeps the layout cue away")
    func fullScreenKeepsTheModeCueAway() {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box) = makeCueCore(isUser: false)
        #expect(core.execute("cycle_mode", args: []).isSuccess)
        #expect(box.cues.isEmpty)
    }

    @Test("set_mode_cue(false) keeps the layout cue away")
    func verbTurnsTheModeCueOff() {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box) = makeCueCore(isUser: true)
        #expect(core.appWide.modeCue)
        let off = core.execute("set_mode_cue", args: [.bool(false)])
        #expect(off.isSuccess)
        #expect(core.appWide.modeCue == false)
        #expect(core.execute("cycle_mode", args: []).isSuccess)
        #expect(box.cues.isEmpty)
        #expect(!core.execute("set_mode_cue", args: []).isSuccess)
    }
}
