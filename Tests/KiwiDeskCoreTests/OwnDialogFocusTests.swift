import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The close-return raise stand-down predicate (#913/#929/#935).
///
/// A hide stands the raise down (macOS picks the next frontmost
/// app itself); an own DIALOG stands it down (raising the
/// background window would submerge a Sparkle alert) — but only
/// the dialog class: the ⌃⌥K shortcuts panel promises the
/// hotkeys keep working while it is open, and the
/// `OwnWindowTiling`-marked Settings window tiles, so neither
/// may bury a close's successor (#935).
///
/// **Why the raise SITE is pinned by a needle instead**
/// (`CloseReturnStandDownWiringTests`): the site is gated on
/// `eventLoop.isListed`, which calls live AX rather than the
/// injected seam, so a driven `handle(…)` never reaches the
/// block for a fabricated pid — an assertion there would pass
/// with the stand-down deleted. The predicate itself is
/// behavior-tested here through the `ownKeyWindow` seam.
@MainActor
@Suite("Close-return raise stand-down (#929/#935)", .serialized)
struct OwnDialogFocusTests {

    private let destroy = KiwiEvent.windowDestroyed(
        WindowID(7),
        wasMinimized: false
    )

    @Test("ownKeyWindowReading is nil in a headless environment")
    func headlessEnvironmentReadsNil() {
        #expect(EventLoop.ownKeyWindowReading() == nil)
    }

    @Test("a hide stands the raise down whatever is key")
    func hideStandsDown() {
        let loop = EventLoop()
        loop.ownKeyWindow = { nil }
        #expect(
            loop.closeReturnRaiseStandsDown(
                after: .windowHidden(WindowID(7))
            )
        )
    }

    @Test("an own dialog stands a close's raise down")
    func ownDialogStandsDown() {
        let loop = EventLoop()
        loop.ownKeyWindow = {
            OwnKeyWindowReading(number: 42, isDialog: true)
        }
        #expect(loop.closeReturnRaiseStandsDown(after: destroy))
    }

    @Test("an own NON-dialog key window lets the raise through")
    func ownNonDialogDoesNotStandDown() {
        let loop = EventLoop()
        // The ⌃⌥K panel / NSColorPanel / Settings reading: key,
        // but outside the dialog class (#935).
        loop.ownKeyWindow = {
            OwnKeyWindowReading(number: 42, isDialog: false)
        }
        #expect(!loop.closeReturnRaiseStandsDown(after: destroy))
    }

    @Test("no own key window lets the raise through")
    func noOwnKeyWindowDoesNotStandDown() {
        let loop = EventLoop()
        loop.ownKeyWindow = { nil }
        #expect(!loop.closeReturnRaiseStandsDown(after: destroy))
    }

    @Test("the dialog class: modal always, panels and the mark never")
    func dialogClassification() {
        // A modal window blocks the app — always a dialog, even
        // a modally-run panel.
        #expect(
            EventLoop.classifiesAsOwnDialog(
                isModal: true,
                isPanel: true,
                isMarkedTilingWindow: false
            )
        )
        // A utility panel (the ⌃⌥K cheat sheet, NSColorPanel)
        // floats above the raise's reach and promises window
        // commands keep working.
        #expect(
            !EventLoop.classifiesAsOwnDialog(
                isModal: false,
                isPanel: true,
                isMarkedTilingWindow: false
            )
        )
        // The OwnWindowTiling-marked window tiles; the raise
        // beside it is the layout's own behavior.
        #expect(
            !EventLoop.classifiesAsOwnDialog(
                isModal: false,
                isPanel: false,
                isMarkedTilingWindow: true
            )
        )
        // Everything else own-and-key — Sparkle's alerts, the
        // tour, Config Issues — is the #929 dialog class.
        #expect(
            EventLoop.classifiesAsOwnDialog(
                isModal: false,
                isPanel: false,
                isMarkedTilingWindow: false
            )
        )
    }
}
