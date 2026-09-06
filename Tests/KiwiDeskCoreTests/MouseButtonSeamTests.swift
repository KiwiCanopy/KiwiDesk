import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The mouse-button read is one injected seam
/// (`MouseTracker.pressedButtons`, #1103/#1199), and its two
/// gesture consumers reach it rather than `NSEvent`.
///
/// Neither is otherwise observable: `isResizeGesture`'s held-button
/// arm returns before every input a fixture controls, and
/// `drag.isMousePressed` is wired once at bootstrap, so a wiring
/// that went back to the live read would leave every drag and
/// resize suite green while the developer's hand decided their
/// verdicts again. The warp's own branch is pinned by
/// `MouseFollowsFocusTests`, the suite #1199 was filed against.
@Suite("Mouse-button seam (#1103/#1199)", .serialized)
@MainActor
struct MouseButtonSeamTests {
    @Test("isResizeGesture reads the seam, left button only")
    func resizeGestureFollowsTheSeam() {
        let core = makeTestCore()
        let id = WindowID(1)
        // No press recorded, so the trailing-event branch cannot
        // answer: the button is the only thing left to say yes.
        #expect(!core.isResizeGesture(id))
        core.mouse.pressedButtons = { 1 }
        #expect(core.isResizeGesture(id))
        // A right-click is not a resize drag.
        core.mouse.pressedButtons = { 1 << 1 }
        #expect(!core.isResizeGesture(id))
    }

    @Test("The drag pipeline's press check reads the seam")
    func dragPressCheckFollowsTheSeam() {
        let core = makeTestCore()
        #expect(!core.drag.isMousePressed())
        core.mouse.pressedButtons = { 1 }
        #expect(core.drag.isMousePressed())
        core.mouse.pressedButtons = { 1 << 1 }
        #expect(!core.drag.isMousePressed())
    }
}
