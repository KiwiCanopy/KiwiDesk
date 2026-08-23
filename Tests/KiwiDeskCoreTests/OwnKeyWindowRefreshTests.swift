import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ring stand-down's TRIGGER (#933 follow-up): an own
/// window taking or resigning key re-evaluates the ring set via
/// the `NSWindow` key notifications, because Sparkle's update
/// alert can take key without producing a single `KiwiEvent` —
/// the suppression predicate was right and simply never re-ran
/// (device QA, 2026-08-22). Asserted through
/// `BorderManager.specs`, which `sync` stores unconditionally.
@Suite("Own key window ring refresh (#933)", .serialized)
@MainActor
struct OwnKeyWindowRefreshTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-own-key-refresh-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "App"
                )
            )
        )
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        return core
    }

    @Test("A key-window change re-evaluates the ring set")
    func keyChangeRefreshesRings() {
        let core = makeCore()
        core.updateBorders()
        #expect(core.borders.specs[WindowID(1)] != nil)
        // An own untracked window takes key: the posted
        // notification alone must stand the ring down — no
        // KiwiEvent fires in Sparkle's no-update flow.
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 999_999, isDialog: true)
        }
        NotificationCenter.default.post(
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        #expect(core.borders.specs[WindowID(1)] == nil)
        // Dismissed (key resigned, no app switch): the ring
        // returns the same way.
        core.eventLoop.ownKeyWindow = { nil }
        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        #expect(core.borders.specs[WindowID(1)] != nil)
    }
}
