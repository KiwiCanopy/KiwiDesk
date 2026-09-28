import CoreFoundation
import Foundation
import Testing

@testable import KiwiDeskCore

/// The scroll tap's deadline fires again after its first firing
/// (#1656): a one-shot CFRunLoop timer dies at its first callout,
/// and every gesture after the first would then never end.
///
/// Driven on a run loop of its own thread, never the main one, so
/// the suite spends nothing of the shared main actor. The waits
/// are hang-guards (tests.md, #344): each returns the instant the
/// firing lands.
@Suite("Scroll expiry timer")
struct ScrollExpiryTimerTests {
    private final class Loop: @unchecked Sendable {
        let fired = DispatchSemaphore(value: 0)
        let ready = DispatchSemaphore(value: 0)
        var runLoop: CFRunLoop?
        var timer: ScrollExpiryTimer?

        func start() {
            Thread { [self] in
                runLoop = CFRunLoopGetCurrent()
                timer = ScrollExpiryTimer(on: runLoop!) { [self] in
                    fired.signal()
                }
                ready.signal()
                CFRunLoopRun()
            }.start()
            ready.wait()
        }

        /// Re-arms on the timer's own thread, as the tap does.
        func arm(in seconds: Double) {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue)
            { [self] in
                timer?.arm(at: CFAbsoluteTimeGetCurrent() + seconds)
            }
            CFRunLoopWakeUp(runLoop)
        }

        func stop() {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue)
            { [self] in
                timer?.invalidate()
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    @Test("a second deadline fires after the first did")
    func refires() {
        let loop = Loop()
        loop.start()
        defer { loop.stop() }
        for _ in 0..<3 {
            loop.arm(in: 0.01)
            #expect(loop.fired.wait(timeout: .now() + 30) == .success)
        }
    }

    @Test("an unarmed timer stays quiet")
    func idleIsQuiet() {
        let loop = Loop()
        loop.start()
        defer { loop.stop() }
        loop.arm(in: 0.01)
        _ = loop.fired.wait(timeout: .now() + 30)
        #expect(loop.fired.wait(timeout: .now() + 0.2) == .timedOut)
    }
}
