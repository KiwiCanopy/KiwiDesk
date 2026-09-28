import SwiftUI

/// Places a gesture entry's children — picture, sentence and at most
/// one control — with the control under the sentence when its ideal
/// width fits the sentence's column, and under the whole row when
/// it does not (a long locale, a narrow window). One layout rather
/// than two subtrees, so the control keeps its identity, and so its
/// focus, when the arrangement changes (#1726; the reason
/// `SettingsRowShape` swaps an `AnyLayout`, never an `if`).
struct GestureEntryLayout: Layout {
    var spacing: CGFloat = 14
    var rowSpacing: CGFloat = 8
    /// The width an unconstrained probe (a `.fixedSize()` ancestor)
    /// is answered at: a Settings pane's column, so the answer is a
    /// size the entry is actually drawn at.
    static let idealWidth: CGFloat = 480

    private struct Measure {
        let plate: CGSize
        let sentence: CGSize
        /// The control's size at the width it is placed at, so a
        /// label that wraps there is measured wrapped.
        let control: CGSize
        let column: CGFloat
        let inColumn: Bool
    }

    private func measure(
        _ width: CGFloat,
        _ subviews: Subviews
    ) -> Measure {
        assert(subviews.count <= 3, "an entry takes one control")
        let plate = subviews[0].sizeThatFits(.unspecified)
        let column = max(width - plate.width - spacing, 0)
        let sentence = subviews[1].sizeThatFits(
            ProposedViewSize(width: column, height: nil)
        )
        // An entry with no control passes `EmptyView`, which is no
        // subview at all rather than an empty one.
        guard subviews.count > 2 else {
            return Measure(
                plate: plate,
                sentence: sentence,
                control: .zero,
                column: column,
                inColumn: true
            )
        }
        let ideal = subviews[2].sizeThatFits(.unspecified)
        let inColumn = Self.fitsColumn(
            control: ideal.width,
            plate: plate.width,
            width: width,
            spacing: spacing
        )
        let placed = min(ideal.width, inColumn ? column : width)
        let control = subviews[2].sizeThatFits(
            ProposedViewSize(width: placed, height: nil)
        )
        return Measure(
            plate: plate,
            sentence: sentence,
            control: CGSize(width: placed, height: control.height),
            column: column,
            inColumn: inColumn
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

    /// Where the control's top-left goes: under the sentence, at
    /// the column's leading edge, or under the whole row at the
    /// entry's leading edge.
    static func controlOrigin(
        inColumn: Bool,
        in bounds: CGRect,
        plate: CGSize,
        sentence: CGSize,
        spacing: CGFloat,
        gap: CGFloat
    ) -> CGPoint {
        inColumn
            ? CGPoint(
                x: bounds.minX + plate.width + spacing,
                y: bounds.minY + sentence.height + gap
            )
            : CGPoint(
                x: bounds.minX,
                y: bounds.minY + max(plate.height, sentence.height) + gap
            )
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
        let width = proposal.width ?? Self.idealWidth
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
        guard subviews.count > 2 else { return }
        subviews[2].place(
            at: Self.controlOrigin(
                inColumn: m.inColumn,
                in: bounds,
                plate: m.plate,
                sentence: m.sentence,
                spacing: spacing,
                gap: gap(m.control)
            ),
            proposal: ProposedViewSize(
                width: m.control.width,
                height: m.control.height
            )
        )
    }
}
