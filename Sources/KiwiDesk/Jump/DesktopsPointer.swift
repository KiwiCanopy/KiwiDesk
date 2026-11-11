import SwiftUI

/// What the pointer lifts on the Desktops side (#3209): a Desktop's
/// title, a Space's line or a window's icon, on the Windows rows'
/// grey ground (`KiwiHubPaint.rowHover`). The panel hands it down
/// the side's views; a lift never sits on the selection (#1173).
struct DesktopsPointer {
    var hover: JumpHover?
    var onHover: (JumpHover) -> Void = { _ in }
    var onHoverEnd: (JumpHover) -> Void = { _ in }

    /// Whether `target`, selected or not, draws the lift.
    func lifts(_ target: JumpHover, selected: Bool) -> Bool {
        JumpHover.lifts(
            target,
            hover: hover,
            selected: selected,
            clickable: true
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
