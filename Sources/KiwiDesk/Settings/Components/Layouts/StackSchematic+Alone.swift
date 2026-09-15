import KiwiDeskCore
import SwiftUI

/// The lone-window frame of the Stack schematic (#1389): the one
/// window fills the canvas, or keeps the master zone a second
/// window would leave it — the stack zone drawn empty.
extension StackSchematic {
    var lone: Bool { windows == 1 }

    /// Where the lone window sits, mirroring `StackLayout`'s
    /// lone-master branch (`LayoutSchematicCountTests`).
    func loneFrame(in size: CGSize) -> CGRect {
        guard !fillWhenAlone else {
            return CGRect(origin: .zero, size: size)
        }
        switch stackPosition {
        case .right:
            return CGRect(
                x: 0,
                y: 0,
                width: masterSpan(size.width),
                height: size.height
            )
        case .left:
            let span = masterSpan(size.width)
            return CGRect(
                x: size.width - span,
                y: 0,
                width: span,
                height: size.height
            )
        case .bottom:
            return CGRect(
                x: 0,
                y: 0,
                width: size.width,
                height: masterSpan(size.height)
            )
        case .top:
            let span = masterSpan(size.height)
            return CGRect(
                x: 0,
                y: size.height - span,
                width: size.width,
                height: span
            )
        }
    }

    /// The lone-window sentence switches with the fill toggle
    /// (`LayoutSchematicCaptionTests`).
    var loneCaption: String {
        if fillWhenAlone {
            return L(
                "layout.schematic.stack.caption_alone_fill",
                "One window fills the whole screen."
            )
        }
        return L(
            "layout.schematic.stack.caption_alone_zone",
            "One window keeps the master zone and leaves the "
                + "stack zone empty."
        )
    }

    var loneAxLabel: String {
        if fillWhenAlone {
            return L(
                "layout.schematic.stack.ax_alone_fill",
                "Stack preview: one window filling the whole "
                    + "screen."
            )
        }
        return L(
            "layout.schematic.stack.ax_alone_zone",
            "Stack preview: one window in the master zone at "
                + "%1$d percent, the stack zone empty.",
            SchematicMath.pct(masterRatio)
        )
    }
}
