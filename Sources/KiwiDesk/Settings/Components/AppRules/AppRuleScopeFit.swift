import AppKit

/// A scope label cut in its middle to fit the scope cell (#3415).
/// A borderless `Menu`'s title is drawn by AppKit, which ignores a
/// SwiftUI frame, truncation mode and font on it, so the string
/// arrives already fitted. Main-actor: it measures with AppKit.
@MainActor
enum AppRuleScopeFit {
    /// The font AppKit draws the menu's title in: the control's,
    /// whatever the row's SwiftUI font (`AppRuleScopeCellTests`).
    static var font: NSFont {
        NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }

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
