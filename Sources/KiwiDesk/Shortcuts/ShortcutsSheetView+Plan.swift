import CoreGraphics

/// The sheet's sections as KiwiHub's column plan reads them
/// (#3570 ▸ Ruling 5): estimated from their parts, never measured.
extension ShortcutsSheetView {
    /// The caption font's line height and its mean advance per
    /// character, measured on macOS 27 (`ShortcutsSheetEstimateTests`).
    static let titleLine: CGFloat = 16
    static let captionLine: CGFloat = 12
    static let captionAdvance: CGFloat = 5.5

    /// A section's estimated parts, for KiwiHub's column plan: the
    /// title, a caption wrapped at `width`, and its rows.
    static func planned(
        _ section: Section,
        needle: String,
        width: CGFloat
    ) -> ShortcutsColumnPlan.Section {
        var header = titleLine + titleGap
        if let caption = section.caption, needle.isEmpty {
            let lines = (CGFloat(caption.count) * captionAdvance / width)
                .rounded(.up)
            header += partSpacing + lines * captionLine + captionGap
        }
        return ShortcutsColumnPlan.Section(
            header: header,
            rows: section.rows.count,
            pitch: partSpacing + rowHeight,
            continued: titleLine + titleGap
        )
    }
}
