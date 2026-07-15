import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #177: Settings is a tracked float; KiwiDesk's panels,
/// overlays, and border windows remain fully ignored. Accessory
/// apps with real windows (including Tailscale) are observable.
@Suite("Own-window and accessory-app classification (#177)")
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

    @Test("Own main windows are managed; own panels stay ignored")
    func ownWindowClassification() {
        #expect(
            !EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: true
            )
        )
        #expect(
            EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: false
            )
        )
    }

    @Test("Accessory apps attach after a standard window appears")
    func accessoryAttachment() {
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .regular,
                hasStandardWindow: false
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .accessory,
                hasStandardWindow: false
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .accessory,
                hasStandardWindow: true
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .prohibited,
                hasStandardWindow: true
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: getpid(),
                activationPolicy: .accessory,
                hasStandardWindow: false
            )
        )
    }

    @Test("Accessory and own-process windows force floating")
    func forceFloatPolicy() {
        #expect(
            EventLoop.shouldForceFloat(
                pid: 1,
                activationPolicy: .accessory
            )
        )
        #expect(
            EventLoop.shouldForceFloat(
                pid: getpid(),
                activationPolicy: .regular
            )
        )
        #expect(
            !EventLoop.shouldForceFloat(
                pid: 1,
                activationPolicy: .regular
            )
        )
    }
}
