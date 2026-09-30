import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// Shadow windows in the loop (#1785): the verdict `track` asks,
/// its wait, its records and what forgets them. The rule itself
/// is `ShadowRuleTests`'; split at the file ceiling. Driven
/// through the loop's seams; AX elements appear only as inert
/// values the fakes key on.
@MainActor
@Suite("Shadow windows (#1785)")
struct ShadowWindowTests {
    private let frame = CGRect(x: 75, y: 86, width: 821, height: 1025)

    private func traits(
        _ id: UInt32,
        buttons: Bool?,
        children: Int?,
        frame: CGRect? = nil
    ) -> WindowTraits {
        WindowTraits(
            id: WindowID(id),
            hasTitlebarButton: buttons,
            childCount: children,
            frame: frame ?? self.frame
        )
    }

    // MARK: - The loop

    private let pid: pid_t = 178_701

    @MainActor
    private final class Box {
        var windows: [WindowTraits]
        var listed: [Int]
        var siblingReads = 0
        var traitReads: [WindowID] = []
        var retracks = 0
        var logs: [String] = []
        var now = ContinuousClock.now
        init(_ windows: [WindowTraits]) {
            self.windows = windows
            listed = Array(windows.indices)
        }
    }

    private func makeLoop(
        _ windows: [WindowTraits]
    ) -> (loop: EventLoop, elements: [AXUIElement], box: Box) {
        let loop = EventLoop()
        let box = Box(windows)
        loop.onLog = { box.logs.append($0) }
        loop.onTransientDrop = { box.retracks += 1 }
        loop.monotonicNow = { box.now }
        // Distinct inert elements, one per window, keyed by index.
        let elements = windows.indices.map { index in
            AXUIElementCreateApplication(pid_t(900_000 + index))
        }
        loop.axWindows = { _ in
            box.siblingReads += 1
            return box.listed.map { elements[$0] }
        }
        loop.shadows.traits = { element, _ in
            let index = elements.firstIndex { CFEqual($0, element) }
            let traits = index.map { box.windows[$0] }
            if let traits { box.traitReads.append(traits.id) }
            return traits
        }
        return (loop, elements, box)
    }

    private func verdict(
        _ loop: EventLoop,
        _ elements: [AXUIElement],
        _ box: Box,
        _ index: Int
    ) -> ShadowVerdict {
        loop.shadowVerdict(
            elements[index],
            id: box.windows[index].id,
            pid: pid
        )
    }

    @Test("the loop records a shadow and says so once")
    func loopRecordsTheShadow() {
        let host = traits(889_401, buttons: true, children: 6)
        let twin = traits(889_398, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([host, twin])
        #expect(verdict(loop, elements, box, 0) == .window)
        #expect(verdict(loop, elements, box, 1) == .shadow)
        #expect(verdict(loop, elements, box, 1) == .shadow)
        #expect(loop.shadows.holds(twin.id, pid: pid))
        #expect(!loop.shadows.holds(host.id, pid: pid))
        // Another process's same id is not this one's shadow.
        #expect(!loop.shadows.holds(twin.id, pid: pid + 1))
        #expect(box.logs.filter { $0.hasPrefix("shadow:") }.count == 1)
    }

    @Test("a window with a button or content reads no siblings")
    func realWindowsReadNoSiblings() {
        let buttoned = traits(1, buttons: true, children: 6)
        let content = traits(2, buttons: false, children: 3)
        let (loop, elements, box) = makeLoop([buttoned, content])
        #expect(verdict(loop, elements, box, 0) == .window)
        #expect(verdict(loop, elements, box, 1) == .window)
        #expect(box.siblingReads == 0)
        #expect(box.traitReads == [buttoned.id, content.id])
    }

    @Test("a lone shell waits for a host, then tiles")
    func loneShellWaitsThenTiles() {
        let frameless = traits(1, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([frameless])
        #expect(verdict(loop, elements, box, 0) == .deferred)
        #expect(box.retracks == 1)
        box.now = box.now.advanced(by: .seconds(2))
        #expect(verdict(loop, elements, box, 0) == .deferred)
        box.now = box.now.advanced(by: ShadowWindows.hostWait)
        #expect(verdict(loop, elements, box, 0) == .window)
        // Tracked: its own focus reports must not read as a
        // shadow's.
        #expect(!loop.shadows.holds(frameless.id, pid: pid))
    }

    @Test("a lone shell beside a tracked window of its app tiles at once")
    func loneShellPastLaunchTilesAtOnce() {
        let tracked = traits(1, buttons: false, children: 0)
        let frameless = traits(2, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([tracked, frameless])
        // A decoration-less terminal's second window: its first
        // is already a tile, so nothing of its app lists late.
        loop.elements[pid] = [tracked.id: elements[0]]
        #expect(verdict(loop, elements, box, 1) == .window)
        #expect(!loop.shadows.holds(frameless.id, pid: pid))
        #expect(box.retracks == 0)
    }

    @Test("an unanswered read beside a tracked window still waits")
    func unreadPastLaunchStillWaits() {
        let tracked = traits(1, buttons: true, children: 6)
        let unread = traits(2, buttons: nil, children: nil)
        let (loop, elements, box) = makeLoop([tracked, unread])
        loop.elements[pid] = [tracked.id: elements[0]]
        // Orion's fresh twin, its read timing out as it leaves the
        // list: no verdict, so no tile.
        #expect(verdict(loop, elements, box, 1) == .deferred)
        #expect(box.retracks == 1)
    }

    @Test("a shell whose host lists late is a shadow on the re-track")
    func lateHostMakesAShadow() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([twin, host])
        box.listed = [0]
        #expect(verdict(loop, elements, box, 0) == .deferred)
        box.listed = [0, 1]
        #expect(verdict(loop, elements, box, 0) == .shadow)
    }

    @Test("an unanswered read waits, never tiles a known shadow")
    func unreadNeverTakesAVerdictBack() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([host, twin])
        #expect(verdict(loop, elements, box, 1) == .shadow)
        // The twin leaves the list mid-read, long after.
        box.windows[1] = traits(2, buttons: nil, children: nil)
        box.now = box.now.advanced(by: .seconds(60))
        #expect(verdict(loop, elements, box, 1) == .shadow)
        box.now = box.now.advanced(by: .seconds(60))
        #expect(verdict(loop, elements, box, 1) == .shadow)
    }

    @Test("only readings with no verdict between them spend the wait")
    func aVerdictEndsTheWait() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: nil, children: nil)
        let (loop, elements, box) = makeLoop([host, twin])
        // Device, 02:34:36: unread once, as the twin left the list.
        #expect(verdict(loop, elements, box, 1) == .deferred)
        box.windows[1] = traits(2, buttons: false, children: 0)
        #expect(verdict(loop, elements, box, 1) == .shadow)
        // 02:34:44: unread again, eight seconds on. Forget the
        // record, so the wait alone decides.
        loop.shadows.clear(twin.id, pid: pid)
        box.windows[1] = traits(2, buttons: nil, children: nil)
        box.now = box.now.advanced(by: .seconds(8))
        #expect(verdict(loop, elements, box, 1) == .deferred)
    }

    @Test("an unanswered window with no verdict tiles after the wait")
    func unreadFailsOpen() {
        let lone = traits(1, buttons: nil, children: nil)
        let (loop, elements, box) = makeLoop([lone])
        #expect(verdict(loop, elements, box, 0) == .deferred)
        box.now = box.now.advanced(by: ShadowWindows.hostWait)
        #expect(verdict(loop, elements, box, 0) == .window)
    }

    @Test("a shadow that gains content becomes a window")
    func contentTakesTheRecordBack() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([host, twin])
        #expect(verdict(loop, elements, box, 1) == .shadow)
        box.windows[1] = traits(2, buttons: false, children: 4)
        #expect(verdict(loop, elements, box, 1) == .window)
        #expect(!loop.shadows.holds(twin.id, pid: pid))
        #expect(loop.hostOfShadow(twin.id, pid: pid) == twin.id)
    }

    @Test("a shadow that left the list keeps its record")
    func unlistedShadowKeepsItsRecord() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let other = traits(3, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([host, twin, other])
        #expect(verdict(loop, elements, box, 1) == .shadow)
        // The twin flickers out while another shell is judged: its
        // record survives, so its return costs no sibling read.
        box.listed = [0, 2]
        #expect(verdict(loop, elements, box, 2) == .shadow)
        #expect(loop.shadows.holds(twin.id, pid: pid))
        #expect(loop.shadows.holds(other.id, pid: pid))
    }

    @Test("detach and stop forget the shadows and the waits")
    func detachAndStopForget() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let lone = traits(3, buttons: false, children: 0)
        let (loop, elements, box) = makeLoop([host, twin, lone])
        #expect(verdict(loop, elements, box, 1) == .shadow)
        loop.detach(pid: pid, restoreEnhancedUI: false)
        #expect(!loop.shadows.holds(twin.id, pid: pid))
        box.listed = [2]
        #expect(verdict(loop, elements, box, 2) == .deferred)
        #expect(loop.shadows.holds(lone.id, pid: pid))
        loop.isRunning = true
        loop.stop()
        #expect(loop.shadows.hosts.isEmpty)
        #expect(loop.shadows.firstSeen.isEmpty)
    }
}
