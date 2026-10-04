import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **An off-main reconcile asks the app nothing per window while
/// it applies the list** (#1933). The read that fetched the list
/// also read each tracked window — its id, fullscreen state and
/// shadow traits through the loop's own seams — so the apply on
/// the main actor only compares. Every seam here records whether
/// it was asked inside the delivery, which is the main-actor half.
@Suite("Reconcile snapshot (#1933)")
@MainActor
struct ReconcileSnapshotTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var applying = false
        var reading = false
        /// LaunchServices seams asked outside the off-main read.
        var askedOutsideRead: [String] = []
        /// Seam calls made while the list applied.
        var askedWhileApplying: [String] = []
        var fullscreen = false
        var policy: NSApplication.ActivationPolicy = .regular
        var hidden = false
        var traitReads = 0
        var events: [String] = []
        /// Read work held back, where a test pumps it by hand.
        var held: [@Sendable () -> Void]?

        func asked(_ seam: String) {
            if applying { askedWhileApplying.append(seam) }
        }
    }

    private let pid: pid_t = 727_727
    private let first = WindowID(41)
    private let second = WindowID(42)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.snapshot", name: "Snapshot")
    }
    private var elementOne: AXUIElement {
        AXUIElementCreateApplication(901_001)
    }
    private var elementTwo: AXUIElement {
        AXUIElementCreateApplication(901_002)
    }

    /// A loop tracking two windows of `pid`, both listed, every
    /// read pumped synchronously and the delivery marked.
    private func makeLoop(
        policy: NSApplication.ActivationPolicy = .regular
    ) -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        box.policy = policy
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        // LaunchServices answers on the read's thread (#1936).
        loop.activationPolicy = { _ in
            MainActor.assumeIsolated {
                box.asked("policy")
                if !box.reading { box.askedOutsideRead.append("policy") }
                return box.policy
            }
        }
        loop.onScreenNormalWindowIDs = { [:] }
        loop.appIsHidden = { _ in
            MainActor.assumeIsolated {
                box.asked("hidden")
                if !box.reading { box.askedOutsideRead.append("hidden") }
                return box.hidden
            }
        }
        loop.frontmostPID = { nil }
        loop.processIdentity.runs = { _ in true }
        let one = elementOne
        let two = elementTwo
        let (first, second) = (first, second)
        loop.axWindows = { _ in [one, two] }
        loop.resolveWindowID = { element in
            MainActor.assumeIsolated { box.asked("id") }
            return CFEqual(element, one) ? first : second
        }
        loop.readFullscreen = { _ in
            MainActor.assumeIsolated {
                box.asked("fullscreen")
                return box.fullscreen
            }
        }
        loop.shadows.traits = { _, id in
            MainActor.assumeIsolated {
                box.asked("traits")
                box.traitReads += 1
            }
            return id.map {
                WindowTraits(
                    id: $0,
                    hasTitlebarButton: true,
                    childCount: 3,
                    frame: .zero
                )
            }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated {
                box.applying = true
                work()
                box.applying = false
            }
        }
        loop.axReads.dispatchOverride = { _, work in
            MainActor.assumeIsolated {
                if box.held != nil {
                    box.held?.append(work)
                } else {
                    box.reading = true
                    work()
                    box.reading = false
                }
            }
        }
        loop.onEvent = { event in
            switch event {
            case .windowFullscreenChanged(let id, let on):
                box.events.append("fullscreen w\(id.raw) \(on)")
            case .windowFloatChanged(let id, let on):
                box.events.append("float w\(id.raw) \(on)")
            case .windowDestroyed(let id, _):
                box.events.append("destroyed w\(id.raw)")
            case .windowHidden(let id):
                box.events.append("hidden w\(id.raw)")
            default: break
            }
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: policy,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.elements[pid] = [first: one, second: two]
        return (loop, box)
    }

    @Test("the apply asks no per-window seam")
    func applyAsksNothingPerWindow() {
        let (loop, box) = makeLoop()
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.askedWhileApplying.isEmpty, "\(box.askedWhileApplying)")
        // Both windows stayed: the read resolved them.
        #expect(!box.events.contains { $0.hasPrefix("destroyed") })
        // Two listed windows: the shadow traits were read once each.
        #expect(box.traitReads == 2)
    }

    @Test("a fullscreen flip read off main still lands")
    func fullscreenFlipLands() {
        let (loop, box) = makeLoop()
        box.fullscreen = true
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.events.contains("fullscreen w41 true"))
        #expect(box.events.contains("fullscreen w42 true"))
        #expect(loop.detectedFullscreen[first] == true)
    }

    @Test("the float verdict read off main matches the main-actor one")
    func floatVerdictMatchesTheSyncPath() {
        // The fabricated elements answer no role, so detection
        // calls them panels on either path.
        let (offMain, box) = makeLoop()
        offMain.reconcileOffMain(pid: pid, app: ref)
        let (sync, _) = makeLoop()
        sync.reconcile(pid: pid, app: ref)
        #expect(box.events.contains("float w41 true"))
        for id in [first, second] {
            #expect(offMain.detectedFloating[id] == sync.detectedFloating[id])
        }
    }

    @Test("the synchronous reconcile still reads on its own thread")
    func syncPathStillReads() {
        // The negative control: without a prefetched read the
        // apply asks the seams itself.
        let (loop, box) = makeLoop()
        box.applying = true
        loop.reconcile(pid: pid, app: ref)
        #expect(box.askedWhileApplying.contains("fullscreen"))
        #expect(box.askedWhileApplying.contains("id"))
    }

    @Test("a reading older than a main-actor write does not revert it")
    func staleReadingDoesNotRevert() {
        let (loop, box) = makeLoop()
        box.held = []
        loop.reconcileOffMain(pid: pid, app: ref)
        // During the flight a synchronous reconcile reads the
        // window entering fullscreen; the held read saw it before.
        box.fullscreen = true
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.detectedFullscreen[first] == true)
        box.fullscreen = false
        box.events = []
        for work in box.held ?? [] { work() }
        #expect(loop.detectedFullscreen[first] == true)
        #expect(!box.events.contains("fullscreen w41 false"))
    }

    @Test("a reading with no fresher write still applies")
    func readingAppliesWithoutAFresherWrite() {
        // The negative control for the stale-reading skip.
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[first] = true
        box.held = []
        loop.reconcileOffMain(pid: pid, app: ref)
        for work in box.held ?? [] { work() }
        #expect(loop.detectedFullscreen[first] == false)
        #expect(box.events.contains("fullscreen w41 false"))
    }

    @Test("a frame write during the read vetoes only the frame")
    func frameWriteVetoesOnlyTheFrame() {
        let (loop, box) = makeLoop()
        box.held = []
        loop.reconcileOffMain(pid: pid, app: ref)
        // The move arm delivers a fresh frame during the flight.
        let moved = CGRect(x: 7, y: 7, width: 300, height: 200)
        loop.trackedFrames[first] = moved
        loop.offMain.noteFreshWrite(first, [.frame])
        box.fullscreen = true
        for work in box.held ?? [] { work() }
        // The reading's fullscreen state still lands.
        #expect(loop.detectedFullscreen[first] == true)
        // The fresher frame stands over the reading's.
        #expect(loop.trackedFrames[first] == moved)
    }

    @Test("the force-float override decides the read verdict too")
    func forceFloatDecidesTheReadVerdict() {
        // An accessory app's windows float as such on either path:
        // the reading's detection never skips the override.
        let (offMain, _) = makeLoop(policy: .accessory)
        offMain.reconcileOffMain(pid: pid, app: ref)
        let (sync, _) = makeLoop(policy: .accessory)
        sync.reconcile(pid: pid, app: ref)
        #expect(offMain.detectedFloating[first] == .floats(.accessoryApp))
        #expect(
            offMain.detectedFloating[first] == sync.detectedFloating[first]
        )
    }

    @Test("the reading files the app's policy and hidden state")
    func readingCarriesPolicyAndHidden() {
        let (loop, box) = makeLoop()
        box.policy = .accessory
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(loop.policy(of: pid) == .accessory)
        box.hidden = true
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.events.contains("hidden w41"))
        #expect(box.askedWhileApplying.isEmpty, "\(box.askedWhileApplying)")
        // Both are read on the read's own thread, never at request.
        #expect(box.askedOutsideRead.isEmpty, "\(box.askedOutsideRead)")
    }
}
