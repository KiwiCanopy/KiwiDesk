import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The boot queue admits only apps a pass can act on.
///
/// `NSWorkspace`'s list is mostly faceless (`.prohibited`)
/// helpers on a heavy session, and every one of them used to be
/// queued, counted and narrated — "apps: 3 of 145" over a desk
/// showing five. This suite pins the queue-build admission
/// (`EventLoop.bootPassAdmits`) at both passes: prohibited and
/// ignore-listed apps never enter the scan's or the sweep's
/// queue, while an app already holding an observer is always
/// admitted — the sweep's visit is how a newly ignored app is
/// DETACHED (the deferred window-rule re-check,
/// `BootWindowRuleReconcileTests`).
///
/// Main-actor spend (tests.md): three `EventLoop`s over faked
/// seams and a handful of queue drains — no scan, no
/// filesystem walk, no AppKit measurement.
@MainActor
@Suite("Boot queue eligibility")
struct BootScanEligibilityTests {
    /// Inert healthy observer, mirroring `BootScanChunkTests`'
    /// (#675 — health is stated, never defaulted).
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        let needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var lines: [String] = []
        var attached: [pid_t] = []
    }

    private static func app(
        _ index: Int,
        policy: NSApplication.ActivationPolicy
    ) -> RunningApp {
        RunningApp(
            pid: pid_t(600_000 + index),
            activationPolicy: policy,
            ref: AppRef(
                bundleID: "test.kiwi.app\(index)",
                name: "App \(index)"
            )
        )
    }

    /// Every machine seam faked; the app roster is the fixture's
    /// choice. Every fake answers instantly, so budgets are
    /// never in play (tests.md's hang-guard rule).
    private func makeLoop(
        apps: [RunningApp]
    ) -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.lines.append($0) }
        loop.registersWorkspaceObservers = false
        loop.applyAXMessagingTimeout = { _ in }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in [] }
        loop.visiblePIDs = { [] }
        loop.makeObserver = { pid in
            box.attached.append(pid)
            return FakeObserver()
        }
        loop.runningApplications = { apps }
        return (loop, box)
    }

    @Test("prohibited and ignored apps never enter the scan queue")
    func scanQueueAdmitsOnlyAttachableApps() {
        let (loop, box) = makeLoop(apps: [
            Self.app(1, policy: .regular),
            Self.app(2, policy: .accessory),
            Self.app(3, policy: .prohibited),
            Self.app(4, policy: .prohibited),
            Self.app(5, policy: .regular),
        ])
        loop.ignoreRules = IgnoreRules(["test.kiwi.app5"])
        #expect(loop.beginScan())
        defer { loop.stop() }

        // The total IS the narrated number (`BootPhase` reads
        // it), so the filter has to land at queue build, not
        // inside the step.
        #expect(loop.bootScan.total == 2)

        let progress = loop.scanChunk(budget: nil)
        #expect(progress.finished)
        #expect(progress.scanned == 2)
        #expect(box.attached == [600_001, 600_002])
        // The summary reports attaches of ELIGIBLE apps — the
        // same population the count row narrated.
        #expect(
            box.lines.contains {
                $0.hasPrefix(
                    "startup scan: 2 apps attached of 2 eligible"
                )
            }
        )
    }

    @Test("the sweep still visits an attached app the rules now ignore")
    func sweepVisitsAnAttachedAppTheRulesNowIgnore() {
        let apps = [Self.app(1, policy: .regular)]
        let (loop, _) = makeLoop(apps: apps)
        #expect(loop.beginScan())
        defer { loop.stop() }
        #expect(loop.scanChunk(budget: nil).finished)
        #expect(loop.observers[600_001] != nil)

        // The profile's rules land between the passes — the
        // deferred re-check the sweep exists to pay (row 29 of
        // docs/accepted-limitations.md).
        loop.ignoreRules = IgnoreRules(["test.kiwi.app1"])
        #expect(loop.beginSweep())

        // Admitted despite the rules: the visit is the detach.
        // The step must come from the ROSTER (it carries the
        // app's bundle id), not from the orphan-observer loop,
        // which rebuilds from a bare pid: the orphan path is a
        // second net under the same app, and without this
        // clause the admission's observer arm was inert
        // (guard-prover, 2026-08-27).
        #expect(loop.bootScan.total == 1)
        #expect(
            loop.bootScan.pending.first?.name == "test.kiwi.app1"
        )
        #expect(loop.scanChunk(budget: nil).finished)
        #expect(loop.observers[600_001] == nil)
    }

    @Test("a never-attached helper is not queued for the sweep")
    func sweepSkipsNeverAttachedIneligibleApps() {
        let (loop, _) = makeLoop(apps: [
            Self.app(1, policy: .regular),
            Self.app(2, policy: .prohibited),
        ])
        #expect(loop.beginScan())
        defer { loop.stop() }
        #expect(loop.scanChunk(budget: nil).finished)

        #expect(loop.beginSweep())

        // One reconcile step: the helper has no observer to
        // repair, nothing tracked to remove, and can never
        // attach — a step for it is inert queue length.
        #expect(loop.bootScan.total == 1)
    }
}
