import KiwiDeskCore
import SwiftUI

/// An entry followed by its version in brackets, which only a
/// window spanning several versions passes (owner, 2026-09-24),
/// in the notes' English (#1849); the version is drawn quieter.
extension UpdateNotesMarkdown {
    @MainActor
    static func entry(_ markdown: String, version: String?)
        -> AttributedString
    {
        var text = self.text(markdown)
        guard let version else { return text }
        var quiet = AttributedString(
            UpdateNotesEnglish.entryVersion(version)
        )
        quiet.foregroundColor = SettingsTheme.ink3
        text += quiet
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
