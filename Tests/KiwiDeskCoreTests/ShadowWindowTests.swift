import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// Shadow windows (#1785): Orion's "Orion Preview" is an empty,
/// button-less standard window stacked exactly on its real window.
/// The rule must catch that twin and nothing a user would call a
/// window — a frameless app with nothing real beneath it included.
/// Driven through the loop's seams; AX elements appear only as
/// inert values the fakes key on.
@MainActor
@Suite("Shadow windows (#1785)")
struct ShadowWindowTests {
    private let frame = CGRect(x: 1664, y: 102, width: 1354, height: 945)

    private func traits(
        _ id: UInt32,
        buttons: Bool,
        children: Int,
        frame: CGRect? = nil
    ) -> WindowTraits {
        WindowTraits(
            id: WindowID(id),
            hasTitlebarButton: buttons,
            childCount: children,
            frame: frame ?? self.frame
        )
    }

    // MARK: - The rule

    @Test("an empty button-less twin on a real window is a shadow")
    func orionTwinIsAShadow() {
        let host = traits(836_719, buttons: true, children: 6)
        let twin = traits(836_711, buttons: false, children: 0)
        #expect(
            WindowTraits.shadowHost(of: twin, among: [twin, host])
                == WindowID(836_719)
        )
    }

    @Test("a frameless window with nothing beneath it is a window")
    func framelessWindowAloneIsKept() {
        let frameless = traits(1, buttons: false, children: 0)
        #expect(
            WindowTraits.shadowHost(of: frameless, among: [frameless]) == nil
        )
    }

    @Test("a twin at its host's size elsewhere is still a shadow")
    func displacedTwinIsAShadow() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(
            2,
            buttons: false,
            children: 0,
            frame: frame.offsetBy(dx: 400, dy: 0)
        )
        #expect(WindowTraits.shadowHost(of: twin, among: [host]) == host.id)
    }

    @Test("the same-frame host wins over another buttoned window")
    func sameFrameHostWins() {
        let elsewhere = traits(
            1,
            buttons: true,
            children: 6,
            frame: frame.offsetBy(dx: 400, dy: 0)
        )
        let host = traits(2, buttons: true, children: 6)
        let twin = traits(3, buttons: false, children: 0)
        #expect(
            WindowTraits.shadowHost(of: twin, among: [elsewhere, host])
                == host.id
        )
    }

    @Test("content or a button keeps a stacked window a window")
    func contentOrButtonKeepsIt() {
        let host = traits(1, buttons: true, children: 6)
        let withContent = traits(2, buttons: false, children: 3)
        let withButton = traits(3, buttons: true, children: 0)
        let unread = traits(4, buttons: false, children: -1)
        for candidate in [withContent, withButton, unread] {
            #expect(
                WindowTraits.shadowHost(of: candidate, among: [host])
                    == nil
            )
        }
    }

    @Test("two button-less windows never host each other")
    func noHostWithoutButtons() {
        let a = traits(1, buttons: false, children: 0)
        let b = traits(2, buttons: false, children: 0)
        #expect(WindowTraits.shadowHost(of: a, among: [a, b]) == nil)
    }

    @Test("an empty window of another size is a window")
    func otherSizeIsKept() {
        let host = traits(1, buttons: true, children: 6)
        let small = traits(
            2,
            buttons: false,
            children: 0,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        #expect(WindowTraits.shadowHost(of: small, among: [host]) == nil)
    }

    // MARK: - The loop

    private let pid: pid_t = 178_701

    private final class Reads {
        var siblings = 0
        var retracks = 0
    }

    private func makeLoop(
        _ box: [WindowTraits]
    ) -> (loop: EventLoop, elements: [AXUIElement], reads: Reads) {
        let loop = EventLoop()
        let reads = Reads()
        loop.onLog = { _ in }
        loop.onTransientDrop = { reads.retracks += 1 }
        // Distinct inert elements, one per window, keyed by index.
        let elements = box.indices.map { index in
            AXUIElementCreateApplication(pid_t(900_000 + index))
        }
        let byElement = { (element: AXUIElement) -> WindowTraits? in
            elements.firstIndex { CFEqual($0, element) }.map { box[$0] }
        }
        loop.axWindows = { _ in
            reads.siblings += 1
            return elements
        }
        loop.shadows.traits = byElement
        loop.shadows.hasTitlebarButton = {
            byElement($0)?.hasTitlebarButton ?? true
        }
        loop.shadows.childCount = { byElement($0)?.childCount ?? -1 }
        return (loop, elements, reads)
    }

    @Test("the loop records a shadow and maps its focus to the host")
    func loopRecordsAndMaps() {
        let host = traits(836_719, buttons: true, children: 6)
        let twin = traits(836_711, buttons: false, children: 0)
        let (loop, elements, _) = makeLoop([host, twin])
        #expect(
            loop.shadowVerdict(elements[0], id: host.id, pid: pid) == .window
        )
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .shadow
        )
        #expect(loop.hostOfShadow(twin.id, pid: pid) == host.id)
        #expect(loop.hostOfShadow(host.id, pid: pid) == host.id)
        // Another process's same id is not this one's shadow.
        #expect(loop.hostOfShadow(twin.id, pid: pid + 1) == twin.id)
    }

    @Test("a window with a button or content never reads siblings")
    func realWindowsReadNoSiblings() {
        let buttoned = traits(1, buttons: true, children: 6)
        let content = traits(2, buttons: false, children: 3)
        let (loop, elements, reads) = makeLoop([buttoned, content])
        #expect(
            loop.shadowVerdict(elements[0], id: buttoned.id, pid: pid)
                == .window
        )
        #expect(
            loop.shadowVerdict(elements[1], id: content.id, pid: pid)
                == .window
        )
        #expect(reads.siblings == 0)
    }

    @Test("a lone twin waits one re-track, then becomes a window")
    func loneTwinIsDeferredOnce() {
        let frameless = traits(1, buttons: false, children: 0)
        let (loop, elements, reads) = makeLoop([frameless])
        #expect(
            loop.shadowVerdict(elements[0], id: frameless.id, pid: pid)
                == .deferred
        )
        #expect(reads.retracks == 1)
        // The re-track finds it still alone: a frameless real window.
        #expect(
            loop.shadowVerdict(elements[0], id: frameless.id, pid: pid)
                == .window
        )
    }

    @Test("a twin whose host lists late is a shadow on the re-track")
    func lateHostMakesAShadow() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, _) = makeLoop([twin, host])
        let all = elements
        loop.axWindows = { _ in [all[0]] }
        #expect(
            loop.shadowVerdict(elements[0], id: twin.id, pid: pid) == .deferred
        )
        loop.axWindows = { _ in all }
        #expect(
            loop.shadowVerdict(elements[0], id: twin.id, pid: pid) == .shadow
        )
    }

    @Test("a cached shadow that gains content becomes a window")
    func cachedVerdictIsReasked() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, _) = makeLoop([host, twin])
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .shadow
        )
        loop.shadows.childCount = { _ in 4 }
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .window
        )
    }

    @Test("a shadow no longer listed is forgotten")
    func unlistedShadowIsPruned() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let other = traits(3, buttons: false, children: 0)
        let (loop, elements, _) = makeLoop([host, twin, other])
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .shadow
        )
        let all = elements
        loop.axWindows = { _ in [all[0], all[2]] }
        #expect(
            loop.shadowVerdict(elements[2], id: other.id, pid: pid) == .shadow
        )
        #expect(loop.hostOfShadow(twin.id, pid: pid) == twin.id)
    }

    @Test("detach and stop forget the shadows")
    func detachAndStopForget() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements, _) = makeLoop([host, twin])
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .shadow
        )
        loop.detach(pid: pid, restoreEnhancedUI: false)
        #expect(loop.hostOfShadow(twin.id, pid: pid) == twin.id)
        #expect(
            loop.shadowVerdict(elements[1], id: twin.id, pid: pid) == .shadow
        )
        loop.isRunning = true
        loop.stop()
        #expect(loop.shadows.hosts.isEmpty)
    }
}
