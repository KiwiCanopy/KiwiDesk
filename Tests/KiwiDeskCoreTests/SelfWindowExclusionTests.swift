import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #177: Settings is a tracked float; KiwiDesk's panels,
/// overlays, and border windows remain fully ignored. Accessory
/// apps are observed before their first real window appears.
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

    @Test("Windowless accessory apps attach before a window appears")
    func accessoryAttachment() {
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .accessory,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: getpid(),
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .regular,
                isIgnored: true
            )
        )
    }

    @Test("Prohibited transitions and queued callbacks lose ownership")
    func callbackOwnershipTransition() {
        #expect(
            EventLoop.ownsObservation(
                hasObserver: true,
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.ownsObservation(
                hasObserver: true,
                pid: 1,
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.ownsObservation(
                hasObserver: false,
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
    }

    @Test("Own window is never a transient overlay (#315)")
    func ownWindowKeepsRing() {
        // The Settings window floats by default (force-float
        // below) but must NOT classify as a launcher-style
        // overlay — that classification suppresses its focus
        // ring. Any own window that reaches tracking is
        // main-capable by construction.
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: getpid(),
                activationPolicy: .accessory
            )
        )
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: getpid(),
                activationPolicy: .regular
            )
        )
        // Third-party accessory apps stay swept (#300); regular
        // apps never classify structurally.
        #expect(
            EventLoop.classifiesAsOverlay(
                pid: 1,
                activationPolicy: .accessory
            )
        )
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: 1,
                activationPolicy: .regular
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
