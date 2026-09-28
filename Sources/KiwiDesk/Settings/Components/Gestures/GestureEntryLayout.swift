import SwiftUI

/// Places a gesture entry's three children — picture, sentence,
/// control — with the control under the sentence when its ideal
/// width fits the sentence's column, and under the whole row when
/// it does not (a long locale, a narrow window). One layout rather
/// than two subtrees, so the control keeps its identity, and so its
/// focus, when the arrangement changes (#1726; the reason
/// `SettingsRowShape` swaps an `AnyLayout`, never an `if`).
struct GestureEntryLayout: Layout {
    var spacing: CGFloat = 14
    var rowSpacing: CGFloat = 8

    private struct Measure {
        let plate: CGSize
        let sentence: CGSize
        let control: CGSize
        let column: CGFloat
        let inColumn: Bool
    }

    private func measure(
        _ width: CGFloat,
        _ subviews: Subviews
    ) -> Measure {
        let plate = subviews[0].sizeThatFits(.unspecified)
        let column = max(width - plate.width - spacing, 0)
        let sentence = subviews[1].sizeThatFits(
            ProposedViewSize(width: column, height: nil)
        )
        // An entry with no control passes `EmptyView`, which is no
        // subview at all rather than an empty one.
        let control =
            subviews.count > 2
            ? subviews[2].sizeThatFits(.unspecified) : .zero
        return Measure(
            plate: plate,
            sentence: sentence,
            control: control,
            column: column,
            inColumn: Self.fitsColumn(
                control: control.width,
                plate: plate.width,
                width: width,
                spacing: spacing
            )
        )
    }

    /// Whether the control sits under the sentence: its ideal width
    /// fits the column the picture leaves.
    static func fitsColumn(
        control: CGFloat,
        plate: CGFloat,
        width: CGFloat,
        spacing: CGFloat
    ) -> Bool {
        control <= max(width - plate - spacing, 0)
    }

    /// The gap above the control, none when it draws nothing.
    private func gap(_ control: CGSize) -> CGFloat {
        control.height > 0 ? rowSpacing : 0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 480
        let m = measure(width, subviews)
        let height =
            m.inColumn
            ? max(
                m.plate.height,
                m.sentence.height + gap(m.control) + m.control.height
            )
            : max(m.plate.height, m.sentence.height)
                + gap(m.control) + m.control.height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let m = measure(bounds.width, subviews)
        let columnX = bounds.minX + m.plate.width + spacing
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(m.plate)
        )
        subviews[1].place(
            at: CGPoint(x: columnX, y: bounds.minY),
            proposal: ProposedViewSize(width: m.column, height: nil)
        )
        let control =
            m.inColumn
            ? CGPoint(
                x: columnX,
                y: bounds.minY + m.sentence.height + gap(m.control)
            )
            : CGPoint(
                x: bounds.minX,
                y: bounds.minY + max(m.plate.height, m.sentence.height)
                    + gap(m.control)
            )
        guard subviews.count > 2 else { return }
        subviews[2].place(
            at: control,
            proposal: ProposedViewSize(
                width: min(m.control.width, bounds.width),
                height: nil
            )
        )
    }
}
