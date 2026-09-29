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

    @Test("a twin tiled away from its host is still a shadow")
    func displacedTwinIsAShadow() {
        // Tracked before its host appeared, the twin was tiled into
        // a slot of its own and never matched the host's frame again.
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

    // MARK: - The loop

    private let pid: pid_t = 178_701

    private func makeLoop(
        _ box: [WindowTraits]
    ) -> (loop: EventLoop, elements: [AXUIElement]) {
        let loop = EventLoop()
        loop.onLog = { _ in }
        // Distinct inert elements, one per window, keyed by index.
        let elements = box.indices.map { index in
            AXUIElementCreateApplication(pid_t(900_000 + index))
        }
        let byElement = { (element: AXUIElement) -> WindowTraits? in
            elements.firstIndex { CFEqual($0, element) }.map { box[$0] }
        }
        loop.axWindows = { _ in elements }
        loop.shadows.traits = byElement
        loop.shadows.hasTitlebarButton = {
            byElement($0)?.hasTitlebarButton ?? true
        }
        return (loop, elements)
    }

    @Test("the loop records a shadow and maps its focus to the host")
    func loopRecordsAndMaps() {
        let host = traits(836_719, buttons: true, children: 6)
        let twin = traits(836_711, buttons: false, children: 0)
        let (loop, elements) = makeLoop([host, twin])
        #expect(!loop.isShadow(elements[0], id: host.id, pid: pid))
        #expect(loop.isShadow(elements[1], id: twin.id, pid: pid))
        #expect(loop.hostOfShadow(twin.id, pid: pid) == host.id)
        #expect(loop.hostOfShadow(host.id, pid: pid) == host.id)
        // Another process's same id is not this one's shadow.
        #expect(loop.hostOfShadow(twin.id, pid: pid + 1) == twin.id)
    }

    @Test("a real window never pays the sibling read")
    func realWindowReadsNoSiblings() {
        let host = traits(1, buttons: true, children: 6)
        let (loop, elements) = makeLoop([host])
        var siblingReads = 0
        loop.axWindows = { _ in
            siblingReads += 1
            return elements
        }
        #expect(!loop.isShadow(elements[0], id: host.id, pid: pid))
        #expect(siblingReads == 0)
    }

    @Test("detach and stop forget the shadows")
    func detachAndStopForget() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements) = makeLoop([host, twin])
        #expect(loop.isShadow(elements[1], id: twin.id, pid: pid))
        loop.detach(pid: pid, restoreEnhancedUI: false)
        #expect(loop.hostOfShadow(twin.id, pid: pid) == twin.id)
        #expect(loop.isShadow(elements[1], id: twin.id, pid: pid))
        loop.isRunning = true
        loop.stop()
        #expect(loop.shadows.hosts.isEmpty)
    }

    @Test("a twin tracked before its host leaves once the host comes")
    func lateHostRetiresTheTwin() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, elements) = makeLoop([twin, host])
        var destroyed: [WindowID] = []
        loop.onEvent = { event in
            if case .windowDestroyed(let id, _) = event {
                destroyed.append(id)
            }
        }
        // The twin alone: a window as far as anyone can tell.
        loop.axWindows = { _ in [elements[0]] }
        #expect(!loop.isShadow(elements[0], id: twin.id, pid: pid))
        loop.elements[pid] = [twin.id: elements[0]]
        loop.retireShadowSuspects(pid: pid)
        #expect(destroyed.isEmpty)
        // The host arrives and is tracked: the twin is re-asked.
        loop.axWindows = { _ in elements }
        loop.elements[pid]?[host.id] = elements[1]
        loop.retireShadowSuspects(pid: pid)
        #expect(destroyed == [twin.id])
        #expect(loop.elements[pid]?[twin.id] == nil)
        #expect(loop.hostOfShadow(twin.id, pid: pid) == host.id)
    }

    @Test("a frameless window alone is never retired")
    func framelessAloneStays() {
        let frameless = traits(1, buttons: false, children: 0)
        let (loop, elements) = makeLoop([frameless])
        var destroyed = 0
        loop.onEvent = { event in
            if case .windowDestroyed = event { destroyed += 1 }
        }
        #expect(!loop.isShadow(elements[0], id: frameless.id, pid: pid))
        loop.elements[pid] = [frameless.id: elements[0]]
        loop.retireShadowSuspects(pid: pid)
        #expect(destroyed == 0)
        #expect(loop.elements[pid]?[frameless.id] != nil)
    }
}
