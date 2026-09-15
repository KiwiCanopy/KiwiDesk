import KiwiDeskCore
import SwiftUI

/// The lone-window frame of the Stack schematic (#1389): the one
/// window fills the canvas, or keeps the master zone a second
/// window would leave it — the stack zone drawn empty.
extension StackSchematic {
    var lone: Bool { windows == 1 }

    /// Where the lone window sits: the master region the ENGINE's
    /// own split gives it (`StackLayout.regions`, #702), or the
    /// whole canvas (`LayoutSchematicAloneTests`).
    func loneFrame(in size: CGSize) -> CGRect {
        guard !fillWhenAlone else {
            return CGRect(origin: .zero, size: size)
        }
        let total =
            stackPosition.splitsHorizontally ? size.width : size.height
        let span = masterSpan(total)
        return StackLayout.regions(
            usable: CGRect(origin: .zero, size: size),
            position: stackPosition,
            masterSpan: span,
            stackSpan: total - Self.zoneGap - span,
            gap: Self.zoneGap
        ).master
    }

    /// The lone-window sentence switches with the fill toggle
    /// (`LayoutSchematicAloneTests`).
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
