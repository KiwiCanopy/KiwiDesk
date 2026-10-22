import AppKit

/// How many claims of a hover reading fit between the board and the
/// panel's visible bottom (#2532): the reading never leaves the
/// panel, so a key with more than fit ends on a "more" line that
/// points at the row list, and a claim is never cut from its cost.
enum KeyboardHoverFit {
    /// The count of leading groups to draw: every group when all
    /// fit, otherwise as many as fit with the "more" line after them.
    static func shown(
        heights: [CGFloat],
        more: CGFloat,
        spacing: CGFloat,
        available: CGFloat
    ) -> Int {
        let all =
            heights.reduce(0, +)
            + spacing * CGFloat(max(heights.count - 1, 0))
        guard all > available else { return heights.count }
        var used = more
        for (index, height) in heights.enumerated() {
            used += height + spacing
            if used > available { return index }
        }
        return heights.count
    }

    /// The face the reading both draws and is measured in.
    static var font: NSFont { NSFont.preferredFont(forTextStyle: .caption1) }

    /// One line's drawn height at `width` in `font`.
    static func height(of line: String, width: CGFloat) -> CGFloat {
        let rect = (line as NSString).boundingRect(
            with: CGSize(
                width: max(width, 1),
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(rect.height)
    }
}
