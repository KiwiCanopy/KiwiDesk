import KiwiDeskCore
import SwiftUI

/// An entry followed by its version in brackets, which only a
/// window spanning several versions passes (owner, 2026-09-24).
/// One localized frame, since the brackets are punctuation a
/// locale may write differently; the version is drawn quieter.
extension UpdateNotesMarkdown {
    @MainActor
    static func entry(_ markdown: String, version: String?)
        -> AttributedString
    {
        var text = self.text(markdown)
        guard let version else { return text }
        let frame = L("update.window.entry_version", "%1$@ (%2$@)")
        let parts = frame.components(separatedBy: "%1$@")
        guard parts.count == 2 else { return text }
        // Either side may carry the version, whichever order the
        // locale writes.
        let quiet = parts.map { part -> AttributedString in
            var run = AttributedString(
                part.replacingOccurrences(of: "%2$@", with: version)
            )
            run.foregroundColor = SettingsTheme.ink3
            return run
        }
        text = quiet[0] + text + quiet[1]
        return text
    }
}

/// The feed's entries are inline markdown — bold, emphasis, code
/// and links, the subset `appcast-sync`'s `inline` renders.
enum UpdateNotesMarkdown {
    /// Links are underlined so they read as links in the ink
    /// colour rather than the accent, which marks fills only.
    static func text(_ markdown: String) -> AttributedString {
        guard
            var text = try? AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        else { return AttributedString(markdown) }
        for run in text.runs {
            if run.link != nil {
                text[run.range].underlineStyle = .single
            }
            if run.inlinePresentationIntent?.contains(.code) == true {
                text[run.range].backgroundColor = SettingsTheme.sunken
            }
        }
        return text
    }
}
