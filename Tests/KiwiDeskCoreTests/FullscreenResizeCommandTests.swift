import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `resize` and a FLOATING window in NATIVE FULL SCREEN
/// (#670/#1184/#1298) — the two arms the float route used to
/// refuse silently. The tiled paths are
/// `FullscreenResizeTiledTests`'.
///
/// Split out of `FloatingResizeCommandTests` at the 350-line
/// ceiling (tests.md). Its fixture is a copy rather than a
/// shared helper, which is the convention for exactly this: a
/// per-file private builder with no assertions of its own.
@Suite("Fullscreen keyboard resize", .serialized)
@MainActor
struct FullscreenResizeCommandTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    /// Two windows in the given mode; w2 focused with a known
    /// frame, floating per `flag`. The display is pinned
    /// (#531/#523) — the float resize reads `floatBounds`, so an
    /// unpinned fixture makes every expectation a function of
    /// the host screen. The animation engine is disabled so
    /// `animate` applies through the observable `apply` hook.
    private func fullscreenSetup(
        _ core: KiwiCore,
        mode: String,
        flag: Bool,
        applied:
            @escaping @MainActor (
                WindowID, CGRect
            ) -> Void
    ) {
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.execute(
            "set_mode",
            args: [.string("1"), .string(mode)]
        )
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(
            .windowResized(
                WindowID(2),
                CGRect(x: 100, y: 100, width: 600, height: 500)
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.setFloating(WindowID(2), flag)
        core.tiler.settings.animations.onWindowResize = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
    }

    /// A native-fullscreen window is left to its own macOS
    /// Space (#670): it fills one, so the float route has no
    /// frame worth writing — and since #1298 the refusal is CUED
    /// (`windowIsFullscreen`), where #1184's arm returned without
    /// drawing: the window has a frame to draw on, and #1255's
    /// argument that a silent keyboard refusal reads as being
    /// ignored applies.
    ///
    /// Both arms refuse, which is #1184's own ruling rather than
    /// a widening of it: a floating-MODE member answers exactly
    /// as a flag-float does, so standing one arm down alone puts
    /// the divergence back at this one window. This case is the
    /// MODE arm — the flag is cleared, so only the space's mode
    /// can carry it — and the bsp case below is the flag arm,
    /// where the mode cannot. A pair in one mode would select
    /// neither: `applies` is true through the mode term either
    /// way, and the flag would decide nothing (code review).
    ///
    /// The negative twin runs first, so it cannot pass for a
    /// fixture that never resized at all.
    @Test("a fullscreen member is left to its own Space")
    func fullscreenMemberIsLeftAlone() {
        expectFullscreenRefused(mode: "floating", flag: false)
    }

    /// The FLAG arm: a flag-float that goes fullscreen in a
    /// TILED space used to take the float route and set a frame
    /// its app refused. The guard sits in `resize()` ahead of
    /// the float branch (#1298), so this arm meets the same
    /// refusal the tiled paths do. The ratio assertion is the
    /// belt against SHEDDING the route rather than the guard: a
    /// press that drops into `resizeBsp` writes the split ratio
    /// through its unknown-focus fallback and moves the
    /// NEIGHBOURS, which no frame assertion sees.
    ///
    /// The ratio is read off the SESSION store, not the global:
    /// a space with no authored override never writes the
    /// global at all (`KiwiCore+SessionRatioWrite`), so the
    /// obvious assertion on `settings.bsp.splitRatioH` holds
    /// whether or not the write happened — it was written that
    /// way first, and could not fail (code review).
    @Test("a fullscreen flag-float in bsp writes no ratio")
    func fullscreenFlagFloatInBspWritesNoRatio() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        fullscreenSetup(
            core,
            mode: "bsp",
            flag: true
        ) { frames[$0] = $1 }
        // The negative twin: the flag arm carries this one, so
        // a fixture that never resized cannot pass below.
        #expect(
            core.execute(
                "resize",
                args: [.string("x"), .number(200)]
            ).isSuccess
        )
        #expect(frames[WindowID(2)] != nil)

        frames = [:]
        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        core.state.apply(
            .windowFullscreenChanged(
                WindowID(2),
                isFullscreen: true
            )
        )
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error == "the focused window is fullscreen"
        )
        #expect(frames.isEmpty)
        #expect(cues == [.windowIsFullscreen(WindowID(2))])
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.splitRatioH == nil
        )
    }

    /// Resizes the focus, marks it fullscreen, resizes again —
    /// which must refuse, write nothing and cue the one case.
    private func expectFullscreenRefused(
        mode: String,
        flag: Bool
    ) {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        fullscreenSetup(core, mode: mode, flag: flag) {
            frames[$0] = $1
        }
        #expect(
            core.execute(
                "resize",
                args: [.string("y"), .number(150)]
            ).isSuccess
        )
        #expect(frames[WindowID(2)] != nil)

        frames = [:]
        // Armed only for the refused leg — the successful one
        // above cues nothing either way, so an earlier capture
        // would read empty without this leg running at all.
        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        core.state.apply(
            .windowFullscreenChanged(
                WindowID(2),
                isFullscreen: true
            )
        )
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(150)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error == "the focused window is fullscreen"
        )
        #expect(frames.isEmpty)
        // Named for the window, never for the layout: it is not
        // the layout that refused this one (#1298).
        #expect(cues == [.windowIsFullscreen(WindowID(2))])
    }
}
