import AppKit
import Testing

@testable import KiwiDesk

/// The #952 order inside `PanelHandBack.release`: the target is
/// consumed BEFORE `orderOut`, whose resign-key re-enters the
/// close. A test has no real key panel to re-enter, so the
/// re-entry is staged inside the `orderOut` closure itself.
@Suite("Key panel hand-back order")
@MainActor
struct PanelHandBackTests {
    @Test("a close re-entered from orderOut still yields once")
    func reentrantCloseYieldsOnce() {
        let handBack = PanelHandBack(core: makeTestCore())
        let target = NSRunningApplication.current
        handBack.returnTarget = target
        handBack.isAppActive = { true }
        var yielded: [pid_t] = []
        handBack.activateReturnTarget = {
            yielded.append($0.processIdentifier)
        }
        var inner: NSRunningApplication?
        let outer = handBack.release(
            yielding: true,
            distrusting: true
        ) {
            // The resign-key close AppKit fires inside orderOut.
            inner = handBack.release(
                yielding: false,
                distrusting: false
            ) {}
        }
        #expect(outer === target)
        #expect(inner == nil)
        #expect(yielded == [target.processIdentifier])
    }
}
