import AppKit
import SwiftUI

/// What the pointer lifts on the Desktops side (#3209): a Desktop's
/// title, a Space's line or a window's icon, on the Windows rows'
/// grey ground (`KiwiHubPaint.rowHover`). The panel hands it down
/// the side's views; a lift never sits on the selection (#1173).
struct DesktopsPointer {
    var hover: JumpHover?
    var onHover: (JumpHover) -> Void = { _ in }
    var onHoverEnd: (JumpHover) -> Void = { _ in }

    /// Whether `target`, selected or not, draws the lift; one a
    /// click would leave alone never does.
    func lifts(
        _ target: JumpHover,
        selected: Bool,
        clickable: Bool = true
    ) -> Bool {
        JumpHover.lifts(
            target,
            hover: hover,
            selected: selected,
            clickable: clickable
        )
    }
}

extension View {
    /// Reports the pointer over `target` to the panel.
    func desktopsHover(
        _ target: JumpHover,
        _ pointer: DesktopsPointer
    ) -> some View {
        onContinuousHover { phase in
            if case .active = phase {
                pointer.onHover(target)
            } else {
                pointer.onHoverEnd(target)
            }
        }
    }
}

/// The click a Desktops tap answers: its count and modifiers, read
/// only from a mouse event, since `clickCount` traps on any other
/// and VoiceOver's press has no event of its own (#3209).
enum DesktopsClick {
    static func of(
        _ event: NSEvent?
    ) -> (count: Int, modifiers: NSEvent.ModifierFlags) {
        guard let event,
            [.leftMouseUp, .leftMouseDown].contains(event.type)
        else { return (1, []) }
        return (event.clickCount, event.modifierFlags)
    }
}
