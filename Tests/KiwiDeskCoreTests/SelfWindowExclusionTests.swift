import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiDesk must never manage its own windows (#174): opening
/// the Settings window promotes the app to `.regular`, which
/// otherwise slips past the `attach` activation-policy gate and
/// tiles the Settings window, stealing focus on restore. The
/// `attach` and `track` guards both key off `isOwnProcess`.
@Suite("Self-window exclusion (#174)")
struct SelfWindowExclusionTests {
    @Test("The current process is recognized as self")
    func ownProcessIsSelf() {
        #expect(EventLoop.isOwnProcess(getpid()))
    }

    @Test("Other processes are not self")
    func otherProcessesNotSelf() {
        // launchd (pid 1) is never KiwiDesk; nor is any pid
        // other than our own.
        #expect(!EventLoop.isOwnProcess(1))
        #expect(!EventLoop.isOwnProcess(getpid() &+ 1))
    }
}
