import KiwiDeskCore
import SwiftUI

/// The line under KiwiVision ▸ Maximize naming the share and anchor
/// Height or Width takes, read from Layout Defaults ▸ Maximize, the
/// values' one home (#3161). One entry per connected screen shape;
/// a Space's own share (#3090) is not shown. The Default page and a
/// lens's checked Maximize row each hand it the fill they show.
struct KiwiVisionMaximizeSummary: View {
    @ObservedObject var model: SettingsModel
    let fill: VisionMaximize

    var body: some View {
        if let axis = fill.axis,
            let prose = Self.prose(
                fill: fill,
                maximize: model.config.settings.maximize,
                shapes: MaximizeCard.shownShapes(of: model.displays)
            )
        {
            CrossReferenceRow(
                prose: prose,
                linkTitle: MaximizeShareCaption.linkTitle,
                destination: .layoutDefaults,
                row: MaximizeShareCaption.row(axis)
            )
            .font(.caption)
        }
    }

    /// The sentence for `fill`, its link at `CrossReferenceRow
    /// .linkSlot`; nil for Off, Full or no screen.
    static func prose(
        fill: VisionMaximize,
        maximize: MaximizeSettings,
        shapes: [ScreenShape]
    ) -> String? {
        guard let axis = fill.axis, let first = shapes.first else {
            return nil
        }
        let share = { (shape: ScreenShape) in
            MaximizeSharePopUp.glyph(maximize.share(for: axis, on: shape))
        }
        let anchor = { (shape: ScreenShape) in
            MaximizeCard.anchorName(maximize.anchor[shape])
        }
        let slot = CrossReferenceRow.linkSlot
        if shapes.count == 1 {
            return KiwiVisionMaximizeWords.one(
                axis,
                share: share(first),
                anchor: anchor(first),
                shape: MaximizeShapeText.name(first),
                slot: slot
            )
        }
        let anchors = Set(shapes.map { maximize.anchor[$0] })
        let sameAnchor = anchors.count == 1
        let entries = shapes.map { shape in
            sameAnchor
                ? KiwiVisionMaximizeWords.entry(
                    MaximizeShapeText.name(shape),
                    share: share(shape)
                )
                : KiwiVisionMaximizeWords.entry(
                    MaximizeShapeText.name(shape),
                    share: share(shape),
                    anchor: anchor(shape)
                )
        }
        .joined(separator: " · ")
        return sameAnchor
            ? KiwiVisionMaximizeWords.many(
                axis,
                entries: entries,
                anchor: anchor(first),
                slot: slot
            )
            : KiwiVisionMaximizeWords.many(axis, entries: entries, slot: slot)
    }
}

/// The summary's frames, one per axis and shape count (#3161).
@MainActor
enum KiwiVisionMaximizeWords {
    /// One screen shape: "¾ wide · from Center, on Laptop. …".
    static func one(
        _ axis: MaximizeAxis,
        share: String,
        anchor: String,
        shape: String,
        slot: String
    ) -> String {
        switch axis {
        case .height:
            L(
                "kiwivision.maximize.summary.height.one",
                "%1$@ wide · from %2$@, on %3$@. Change in %4$@.",
                share,
                anchor,
                shape,
                slot
            )
        case .width:
            L(
                "kiwivision.maximize.summary.width.one",
                "%1$@ tall · from %2$@, on %3$@. Change in %4$@.",
                share,
                anchor,
                shape,
                slot
            )
        }
    }

    /// Several shapes sharing one anchor:
    /// "Width: Laptop ¾ · Widescreen ⅓ · from Center. …".
    static func many(
        _ axis: MaximizeAxis,
        entries: String,
        anchor: String,
        slot: String
    ) -> String {
        switch axis {
        case .height:
            L(
                "kiwivision.maximize.summary.height.many",
                "Width: %1$@ · from %2$@. Change in %3$@.",
                entries,
                anchor,
                slot
            )
        case .width:
            L(
                "kiwivision.maximize.summary.width.many",
                "Height: %1$@ · from %2$@. Change in %3$@.",
                entries,
                anchor,
                slot
            )
        }
    }

    /// Several shapes whose anchors differ, each entry naming its own.
    static func many(
        _ axis: MaximizeAxis,
        entries: String,
        slot: String
    ) -> String {
        switch axis {
        case .height:
            L(
                "kiwivision.maximize.summary.height.mixed",
                "Width: %1$@. Change in %2$@.",
                entries,
                slot
            )
        case .width:
            L(
                "kiwivision.maximize.summary.width.mixed",
                "Height: %1$@. Change in %2$@.",
                entries,
                slot
            )
        }
    }

    /// One shape's entry: "Laptop ¾".
    static func entry(_ shape: String, share: String) -> String {
        L(
            "kiwivision.maximize.summary.entry",
            "%1$@ %2$@",
            shape,
            share
        )
    }

    /// One shape's entry with its anchor: "Laptop ¾ from Center".
    static func entry(
        _ shape: String,
        share: String,
        anchor: String
    ) -> String {
        L(
            "kiwivision.maximize.summary.entry_anchor",
            "%1$@ %2$@ from %3$@",
            shape,
            share,
            anchor
        )
    }
}
