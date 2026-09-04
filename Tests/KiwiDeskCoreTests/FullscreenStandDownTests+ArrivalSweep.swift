import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop settle's arrival sweep (#1037), pinned HERE
/// because `desktopSettle` reads the process-global `isUser`
/// override past the sweep, and this suite is its one holder
/// (see the file header of `FullscreenStandDownTests.swift`).
/// An extension, not a second suite. The sweep's own arms are
/// `ReconcileAllPrefilterTests`'.
///
/// Main-actor spend: one `makeTestCore` with a started loop on
/// fakes; the settle's retile runs against a pinned display.
extension FullscreenStandDownTests {
    private final class SweepObserver: AppObserving {
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
    private final class SweepBox {
        var queried: [pid_t] = []
        var census: [pid_t: Set<WindowID>] = [:]
    }

    @Test("the Desktop settle sweeps arrivals for a settle still current")
    func settleSweepsArrivals() {
        let showing: pid_t = 1_037_002
        let core = makeCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        core.onLog = { _ in }
        let loop = core.eventLoop
        let box = SweepBox()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in SweepObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { pid in
            box.queried.append(pid)
            return []
        }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { box.census }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        defer { loop.stop() }
        loop.attach(
            pid: showing,
            activationPolicy: .regular,
            ref: AppRef(bundleID: "test.kiwi.1037", name: "Arrival"),
            scanWindowsAtAttach: false
        )
        box.census = [showing: [WindowID(1)]]
        // The settle body past the sweep reads the space verdict;
        // pin it so the branch taken is the user-space one on
        // every host.
        NativeSpaces.activeSpaceIsUserOverride = true
        defer { NativeSpaces.activeSpaceIsUserOverride = nil }
        // A superseded settle (rapid switches) does nothing,
        // the sweep included.
        core.desktopSettle(ifStill: 9_999)
        #expect(box.queried.isEmpty)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(box.queried == [showing])
    }
}
