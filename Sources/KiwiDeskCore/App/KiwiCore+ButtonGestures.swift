import Foundation

/// Where a bound click or side button runs (#3281): the pointer
/// tap decided and swallowed the press; this runs its binding as
/// one step and gives the swallowed left press back to the
/// in-process listeners it deafened.
extension KiwiCore {
    func handleButtonGesture(_ event: PointerButtonEvent) {
        if event.key.input == .click {
            redeliverClick(event)
        }
        guard event.phase == .pressed,
            let action = mouse.gestures.resolved[event.key]
        else { return }
        runGestureStep(event.key, action, toward: event.direction)
    }

    /// The swallowed left press deafened the press record and its
    /// fan-out; both hear it through their own doors (#2764
    /// ruling), as the modifier grab's press does.
    private func redeliverClick(_ event: PointerButtonEvent) {
        switch event.phase {
        case .pressed:
            guard let point = event.location else { return }
            let cocoa = GeometryUtils.axPoint(point)
            mouse.deliverPress(at: cocoa, from: .otherApp)
            mouse.recordDown(at: cocoa, from: .otherApp, clickCount: 1)
        case .released:
            mouse.recordUp(from: .otherApp)
        }
    }
}
