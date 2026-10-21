import AppKit

/// How many lines of a hover reading fit over the lines under the
/// board (#2532): the reading draws over them and never leaves the
/// panel, so a key with more lines than fit ends on a "more" line
/// that points at the row list.
enum KeyboardHoverFit {
    /// The count of leading lines to draw: every line when all fit,
    /// otherwise as many as fit with the "more" line after them.
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

    /// One line's drawn height at `width` in the caption face the
    /// reading uses (SwiftUI `.caption`).
    static func height(of line: String, width: CGFloat) -> CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .caption1)
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
