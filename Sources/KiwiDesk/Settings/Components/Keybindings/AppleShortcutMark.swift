import KiwiDeskCore
import SwiftUI

/// An Apple Shortcut row's mark (#3526): the Shortcut symbol, or a
/// warning where the Shortcuts app no longer lists the stored name
/// — renamed or deleted — the way an inactive Space row reads
/// (`OrphanedShortcuts`). The press refuses with a pill naming it.
struct AppleShortcutMark: View {
    let name: String
    @ObservedObject private var library = AppleShortcutLibrary.shared

    var body: some View {
        if library.isMissing(name) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
                .help(Self.missing(name))
                .accessibilityLabel(Self.missing(name))
        } else if let glyph = ShortcutsReferenceBuilder.icon(
            for: NavCommand(
                label: name,
                lua: AppleShortcutAction.command(name)
            )
        ) {
            // The panel's glyph for its verb, through the one door
            // every shortcut row draws by (#2670, #3267).
            ShortcutGlyphView(glyph: glyph)
                .accessibilityHidden(true)
        }
    }

    /// Why the row does nothing, naming the stored shortcut.
    static func missing(_ name: String) -> String {
        L(
            "shortcuts.apple_shortcut.missing",
            "No shortcut is named \u{201C}%1$@\u{201D} in the "
                + "Shortcuts app, so this does nothing. Rename it back "
                + "there.",
            name
        )
    }
}
