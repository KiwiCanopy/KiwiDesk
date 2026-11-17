import AppKit

/// A scope label cut in its middle to fit the scope cell (#3415).
/// A `Menu` label's title is drawn by AppKit, which ignores a
/// SwiftUI frame or truncation mode on it, so the string arrives
/// already fitted. Main-actor: it measures with AppKit's fonts.
@MainActor
enum AppRuleScopeFit {
    /// The row's own text style, which the label is drawn in.
    static var font: NSFont { NSFont.preferredFont(forTextStyle: .callout) }

    /// `text` whole when it fits `width`, else its head and tail
    /// around "…", the longest such cut that fits.
    static func middle(
        _ text: String,
        width: CGFloat = SettingsMetrics.appRuleScopeLabel,
        font: NSFont = font
    ) -> String {
        guard measure(text, font) > width else { return text }
        let chars = Array(text)
        var low = 0
        var high = chars.count
        while low < high {
            let keep = (low + high + 1) / 2
            if measure(cut(chars, keep), font) <= width {
                low = keep
            } else {
                high = keep - 1
            }
        }
        return cut(chars, low)
    }

    /// `chars` with `keep` of them kept, split head-heavy.
    private static func cut(_ chars: [Character], _ keep: Int) -> String {
        let head = (keep + 1) / 2
        let tail = keep - head
        return String(chars.prefix(head)) + "…"
            + String(chars.suffix(tail))
    }

    private static func measure(_ text: String, _ font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
