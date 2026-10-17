import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// The visible-panel scan's button reader (#2344): it reads the
/// app's window list once, names a tracked element from the map
/// without asking the app, and resolves the rest only as far as
/// the asked id. The trait read itself has no seam, so its call
/// is `VisiblePanelWiringTests`' needle.
@MainActor
@Suite("Visible-panel button reader")
struct PanelButtonReaderTests {
    private let pid: pid_t = 909_919

    /// Distinct elements, told apart by `CFEqual`: each wraps a
    /// pid no process holds.
    private func element(_ index: Int32) -> AXUIElement {
        AXUIElementCreateApplication(909_920 + index)
    }

    private final class Box {
        var listReads = 0
        var asked: [Int] = []
    }

    /// A loop listing `tracked`, then `untracked[0]` (id 31) and
    /// `untracked[1]` (id 32), with the asks counted.
    private func makeLoop() -> (EventLoop, Box) {
        let loop = EventLoop()
        let box = Box()
        let tracked = element(0)
        let untracked = [element(1), element(2)]
        loop.elements[pid] = [WindowID(30): tracked]
        loop.axWindows = { _ in
            box.listReads += 1
            return [tracked] + untracked
        }
        // Every ask is recorded — the tracked element as -1 — so a
        // reader that asks the app about it is seen.
        loop.resolveWindowID = { candidate in
            guard
                let index = untracked.firstIndex(where: {
                    CFEqual($0, candidate)
                })
            else {
                box.asked.append(-1)
                return nil
            }
            box.asked.append(index)
            return WindowID(UInt32(31 + index))
        }
        return (loop, box)
    }

    @Test("a tracked element is named by the map, never asked")
    func trackedIsNeverAsked() {
        let (loop, box) = makeLoop()
        _ = loop.untrackedTitlebarButton(of: pid)(WindowID(31))
        #expect(box.asked == [0])
    }

    @Test("resolution stops at the asked window")
    func stopsAtTheAskedId() {
        let (loop, box) = makeLoop()
        let reader = loop.untrackedTitlebarButton(of: pid)
        _ = reader(WindowID(31))
        #expect(box.asked == [0])
        _ = reader(WindowID(32))
        #expect(box.asked == [0, 1])
    }

    @Test("one list read per scan, and a second ask is cached")
    func listIsReadOnce() {
        let (loop, box) = makeLoop()
        let reader = loop.untrackedTitlebarButton(of: pid)
        #expect(box.listReads == 0)
        _ = reader(WindowID(31))
        _ = reader(WindowID(31))
        _ = reader(WindowID(99))
        #expect(box.listReads == 1)
        #expect(box.asked == [0, 1])
    }

    @Test("a window the app does not list has no button")
    func unlistedHasNoButton() {
        let (loop, _) = makeLoop()
        #expect(!loop.untrackedTitlebarButton(of: pid)(WindowID(99)))
    }
}
