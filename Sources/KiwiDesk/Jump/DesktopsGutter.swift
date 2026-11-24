import AppKit

/// A Desktop title's drawn width in the grid's header column
/// (#3602): callout semibold, as the header draws it.
enum DesktopsGutter {
    static func titleWidth(_ title: String) -> CGFloat {
        let size = NSFont.preferredFont(forTextStyle: .callout).pointSize
        let font = NSFont.systemFont(ofSize: size, weight: .semibold)
        return (title as NSString).size(withAttributes: [.font: font])
            .width.rounded(.up)
    }
}
