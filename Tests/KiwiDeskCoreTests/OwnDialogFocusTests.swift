import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Close-return raise stands down when an own key window / dialog
/// is active on screen (#929).
///
/// When an own transient progress window (e.g. Sparkle's "Checking
/// for updates…") closes to display a newly opened alert (Sparkle's
/// "You're up to date!" dialog), KiwiDesk must not forcefully raise
/// a third-party background window over its own dialog.
///
/// **Why a needle and not a behavior test.** The raise site is
/// gated on `eventLoop.isListed`, which calls live AX
/// (`AXHelper.windows(pid:)`, not the injected seam), so for a
/// fabricated pid the whole block is unreachable and a driven
/// `handle(.windowDestroyed(…))` raises nothing. That gate is the
/// same limit `HiddenAppRaiseTests` and
/// `KiwiCore+CloseReturnRestack`'s doc names. So the predicate is
/// pinned by behavior below, and the raise half by a needle
/// (`OwnDialogFocusWiringTests`, in the GUI target because that is
/// where `SourceScan` lives).
@MainActor
@Suite("Own dialog focus stand-down (#929)", .serialized)
struct OwnDialogFocusTests {

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-own-dialog-\(UUID().uuidString)"
                )
        )
    }

    private func window(
        _ raw: UInt32,
        floating: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(raw),
            pid: pid_t(raw),
            appName: "App\(raw)",
            appBundleID: "app.test.\(raw)",
            title: "W\(raw)",
            isFloating: floating
        )
    }

    @Test("hasOwnActiveKeyWindow returns false in headless environment")
    func headlessEnvironmentReturnsFalse() {
        #expect(!EventLoop.hasOwnActiveKeyWindow())
    }

    @Test(
        "hasOwnKeyWindow seam defaults to false headless and is customizable"
    )
    func seamCanBeCustomized() {
        let loop = EventLoop()
        #expect(!loop.hasOwnKeyWindow())
        loop.hasOwnKeyWindow = { true }
        #expect(loop.hasOwnKeyWindow())
    }
}
