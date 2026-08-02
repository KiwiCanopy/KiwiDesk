import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The windowless-app warmup skip's safety contract (#662).
///
/// The boot scan may skip the expensive AX warmup for an app the
/// WindowServer reports windowless — that skip is safe *only*
/// because a following reconcile warms whatever was skipped.
/// Until this suite, that promise lived in prose alone, so
/// re-timing or dropping the startup sweep would have silently
/// turned the skip into "slow-to-show-a-window Electron apps are
/// never warmed" — the #360 failure by a new route. Everything
/// here drives the funnels through the injected machine seams
/// (tests.md); no real app, observer, or AX call is touched.
@MainActor
@Suite("Windowless-app warmup skip (#662)")
struct StartupWarmupSkipTests {
    /// Inert observer: attach installs it, nothing fires.
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        func observe(window: AXUIElement) {}
        func invalidate() {}
    }

    /// A loop whose machine seams are fakes, plus the write log
    /// the assertions read. The fake app answers the EUI read
    /// with `false` (an Electron shape: answers, tree cold), so
    /// a warmup is visible as the EUI-on write.
    private func makeLoop(
        euiReads: @escaping @MainActor (pid_t) -> Bool? = {
            _ in false
        }
    ) -> (
        loop: EventLoop,
        euiWrites: @MainActor () -> [Bool],
        manualWrites: @MainActor () -> Int,
        windowQueries: @MainActor () -> Int
    ) {
        let loop = EventLoop()
        let box = WriteBox()
        loop.isRunning = true
        loop.onLog = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = euiReads
        loop.writeEnhancedUI = { _, on in
            box.euiWrites.append(on)
        }
        loop.writeManualAX = { _, _ in box.manualWrites += 1 }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        loop.activationPolicy = { _ in .regular }
        return (
            loop,
            { box.euiWrites },
            { box.manualWrites },
            { box.windowQueries }
        )
    }

    @MainActor
    private final class WriteBox {
        var euiWrites: [Bool] = []
        var manualWrites = 0
        var windowQueries = 0
    }

    private let pid: pid_t = 424_242
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.cold", name: "Cold")
    }

    @Test("a skipped app is warmed by the following reconcile")
    func skippedAppIsWarmedByReconcile() {
        let (loop, euiWrites, _, windowQueries) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            hasVisibleWindows: false
        )
        // The skip half: attached (observer installed), but no
        // window query and no warmup ran.
        #expect(loop.observes(pid: pid))
        #expect(windowQueries() == 0)
        #expect(euiWrites().isEmpty)
        // The promise half: the next reconcile of the attached
        // regular app warms it.
        loop.reconcile(pid: pid, app: ref)
        #expect(euiWrites() == [true])
    }

    @Test("a visible app is warmed at attach, not deferred")
    func visibleAppWarmsAtAttach() {
        let (loop, euiWrites, _, _) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            hasVisibleWindows: true
        )
        #expect(euiWrites() == [true])
    }

    @Test("the Chromium warmup fires once across reconciles")
    func chromiumWarmupIsSetOnce() {
        // Chromium never answers the EUI read (#360): the warm
        // is the one-time AXManualAccessibility write.
        let (loop, euiWrites, manualWrites, _) = makeLoop(
            euiReads: { _ in nil }
        )
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            hasVisibleWindows: false
        )
        loop.reconcile(pid: pid, app: ref)
        loop.reconcile(pid: pid, app: ref)
        #expect(manualWrites() == 1)
        #expect(euiWrites().isEmpty)
    }

    @Test("attach before start is inert (#672)")
    func attachBeforeStartIsInert() {
        // The ordering half of the boot fix: loadConfig's
        // pre-start reconcileAll must not attach anything, or
        // the scan's prefilter tests nothing — every app is
        // already attached and warmed with the eager default by
        // the time start() runs.
        let (loop, euiWrites, _, windowQueries) = makeLoop()
        loop.isRunning = false
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref
        )
        #expect(!loop.observes(pid: pid))
        #expect(windowQueries() == 0)
        #expect(euiWrites().isEmpty)
    }
}
