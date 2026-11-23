import CoreGraphics

/// The sheet's sections as KiwiHub's column plan reads them
/// (#3570 ▸ Ruling 5): estimated from their parts, never measured.
extension ShortcutsSheetView {
    /// A section's estimated parts, for KiwiHub's column plan: the
    /// title, a caption wrapped at `width`, and its rows.
    static func planned(
        _ section: Section,
        needle: String,
        width: CGFloat
    ) -> ShortcutsColumnPlan.Section {
        var header: CGFloat = 18
        if let caption = section.caption, needle.isEmpty {
            // About 6.5 pt a character at the caption font.
            let lines = (CGFloat(caption.count) * 6.5 / width).rounded(.up)
            header += 2 + lines * 15 + 4
        }
        return ShortcutsColumnPlan.Section(
            header: header,
            rows: section.rows.count
        )
    }
}
