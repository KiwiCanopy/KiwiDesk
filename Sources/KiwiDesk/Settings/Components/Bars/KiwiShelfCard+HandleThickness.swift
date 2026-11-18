import KiwiDeskCore
import SwiftUI

/// How thick an Auto bar's handle and the Pocket's tab draw
/// (#3451): a stepper in the Show group between Show and Reveal,
/// greyed with its sentence while nothing rests as a handle, as
/// `BarsGates` answers it. A look style path, so a look sets it.
extension KiwiShelfCard {
    @ViewBuilder var handleThicknessRow: some View {
        let gates = BarsGates(
            settings: model.config.settings,
            guiManaged: model.guiManaged
        )
        let reason = gates.inertReason(for: .kiwishelf(.handleThickness))
        let range = KiwiShelf.handleThicknessRange
        StepperRow(
            label: SettingsCatalog.bars.kiwishelfHandleThickness.text,
            value: Binding(
                get: { Int(shelf.wrappedValue.resolvedHandleThickness) },
                set: {
                    shelf.wrappedValue.handleThickness =
                        KiwiShelf.clampHandleThickness(CGFloat($0))
                }
            ),
            in: Int(range.lowerBound)...Int(range.upperBound),
            suffix: L("kiwishelf.handle_thickness.unit", "pt"),
            help: L(
                "kiwishelf.handle_thickness.help",
                "How thick the line is that stands in for a bar or the "
                    + "Pocket at the screen edge while they're hidden. "
                    + "Applying a look sets it."
            )
        )
        .modifier(GreyOut(active: reason != nil))
        .searchAnchored(SettingsCatalog.bars.kiwishelfHandleThickness)
        if let reason {
            caption(reason)
        }
    }
}
