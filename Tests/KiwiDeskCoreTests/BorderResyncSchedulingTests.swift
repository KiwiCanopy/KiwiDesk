import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The border settle passes (#596). The old single heal fired at
/// `durationMS + 50` and did both jobs badly: a spring's visual
/// settle is ~2× its response, so it landed mid-flight — far too
/// early to re-read a slow app's bounds, and (pre-`syncFrame`)
/// itself a backward snap. They are now two passes with separate
/// deferred slots: an early VISIBILITY re-assert, and a late
/// GEOMETRY re-sync off the settle signal.
@Suite("Border settle scheduling")
@MainActor
struct BorderResyncSchedulingTests {
    /// A single tracked, focused window on the active space, at a
    /// known frame — enough for `updateBorders()` /
    /// `updateStickyMarks()` to produce one spec each.
    private func seed(
        _ core: KiwiCore,
        frame: CGRect,
        isSticky: Bool = false
    ) -> WindowID {
        let id = WindowID(1)
        // Pin the display: the heal path runs the real layout
        // through `calculatedFrames`, so an inherited `NSScreen`
        // would make this assert whatever the host happens to be.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        var window = ManagedWindow(
            id: id,
            pid: 100,
            appName: "App",
            title: "Title",
            stickyScope: isSticky ? .global : .none
        )
        window.frame = frame
        core.state.windows.upsert(window)
        core.state.workspaces.add(id, to: "1")
        core.state.workspaces.focus(id, in: "1")
        return id
    }

    /// Puts one animation in flight without a display link, so
    /// `activeCount` is non-zero for the guards under test.
    private func startAnimation(_ core: KiwiCore) {
        core.tiler.animation.animations[DisplayID(1)] = [
            WindowID(1): FrameAnimation(
                from: CGRect(x: 0, y: 0, width: 10, height: 10),
                to: CGRect(x: 100, y: 0, width: 10, height: 10),
                spring: Spring(
                    response: 0.35,
                    dampingFraction: 0.85
                )
            )
        ]
    }

    @Test("The two passes hold separate deferred slots")
    func passesDoNotShareASlot() {
        let core = makeTestCore()
        core.scheduleBorderResync()
        core.scheduleBorderDropReconcile()
        // Sharing one key let whichever landed second cancel the
        // other — silently dropping either the un-hide or the
        // sticky mark's half of the heal.
        #expect(core.deferred.task(for: .borderResync) != nil)
        #expect(core.deferred.task(for: .borderDropSettle) != nil)
        core.deferred.cancelAll()
    }

    @Test("The visibility pass still fires mid-animation")
    func dropReconcileSchedulesWhileAnimating() {
        let core = makeTestCore()
        startAnimation(core)
        #expect(core.tiler.animation.activeCount == 1)
        // Deliberately early: `sync`'s trailing `order` is what
        // un-hides a ring, and `FollowSource.syncFrame` keeps it
        // from moving an animating window's geometry — so landing
        // mid-flight is safe and the un-hide should not wait for
        // the motion to end.
        core.scheduleBorderDropReconcile()
        #expect(core.deferred.task(for: .borderDropSettle) != nil)
        core.deferred.cancelAll()
    }

    @Test("Settling schedules the geometry re-sync")
    func settleSchedulesResync() {
        let core = makeTestCore()
        core.animationsDidSettle()
        #expect(core.deferred.task(for: .borderResync) != nil)
        core.deferred.cancelAll()
    }

    @Test("A window animating inside the grace keeps its frame")
    func resyncLeavesAnAnimatingWindowAlone() {
        let core = makeTestCore()
        let real = CGRect(x: 12, y: 34, width: 500, height: 400)
        let id = seed(core, frame: real)
        core.tiler.settings.borderStyle.enabled = true
        core.updateBorders()
        let commanded = CGRect(x: 700, y: 500, width: 500, height: 400)
        core.borders.apply(id, windowFrame: commanded)
        // A new animation began inside the grace. The body runs
        // anyway — it is deliberately UNGATED on the animation
        // count — and the window is protected per-window by
        // `FollowSource.syncFrame`, which is strictly better: a
        // global gate has an absorbing state (an animation that
        // never settles pins the count and kills the heal
        // app-wide forever, #599).
        startAnimation(core)
        core.runBorderResync()
        #expect(core.borders.lastFrame(id) == commanded)
    }

    @Test("The re-sync re-glues a stranded ring to real state")
    func resyncHealsAStrandedRing() {
        let core = makeTestCore()
        let real = CGRect(x: 12, y: 34, width: 500, height: 400)
        let id = seed(core, frame: real)
        core.tiler.settings.borderStyle.enabled = true
        core.updateBorders()
        // The ring rode our commanded frames out to a target the
        // app never applied — the #596 item 2 strand.
        let stranded = CGRect(x: 900, y: 900, width: 500, height: 400)
        core.borders.apply(id, windowFrame: stranded)
        #expect(core.borders.lastFrame(id) == stranded)
        core.runBorderResync()
        // Back onto the frame the window actually has.
        #expect(core.borders.lastFrame(id) == real)
    }

    @Test("The re-sync heals the sticky mark too")
    func resyncHealsAStrandedMark() {
        let core = makeTestCore()
        let real = CGRect(x: 12, y: 34, width: 500, height: 400)
        let id = seed(core, frame: real, isSticky: true)
        core.tiler.settings.stickyStyle.mark = true
        core.updateStickyMarks()
        let stranded = CGRect(x: 900, y: 900, width: 500, height: 400)
        core.stickyMarks.reposition(id, windowFrame: stranded)
        #expect(core.stickyMarks.lastFrame(id) == stranded)
        // Deleting `updateStickyMarks()` from the body leaves the
        // ring's heal green and the mark stranded forever.
        core.runBorderResync()
        #expect(core.stickyMarks.lastFrame(id) == real)
    }

    @Test("The grace outlasts a slow app's post-settle catch-up")
    func resyncDelayCoversTheCatchUpWindow() {
        // 100–300 ms on Electron/WebKit; 213 ms measured on device
        // for a frozen-then-resumed app. Reading sooner reads
        // bounds the app has not caught up to — the backward snap.
        #expect(KiwiCore.borderResyncDelayMS >= 300)
    }
}
