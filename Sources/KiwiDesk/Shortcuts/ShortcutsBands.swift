import KiwiDeskCore
import SwiftUI

/// Shortcut reference row display (`ShortcutRow`).
struct ShortcutRowView: View {
    let row: ShortcutRow
    /// The Shortcuts side's query, drawn bold in the name (#2246).
    @Environment(\.shortcutMatch) private var match

    var body: some View {
        HStack(spacing: 8) {
            leadingGlyph
                .frame(width: 20, height: 20)
            Text(label)
                .font(
                    row.monospaced
                        ? .system(.callout, design: .monospaced)
                        : .callout
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel(row.spokenLabel ?? row.label)
            Spacer(minLength: 12)
            if let accessory = row.accessoryIcon {
                Image(systemName: accessory)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help(row.accessoryHelp)
            }
            Text(row.combo)
                .font(.callout)
                .foregroundStyle(.secondary)
                // `R⌘H` reads as a bare letter (#2601).
                .accessibilityLabel(SidedChordWords.label(row.combo))
                .help(SidedChordWords.help(row.combo))
        }
        .help(row.monospaced ? row.label : "")
        .opacity(row.unavailable ? 0.55 : 1)
        .accessibilityHint(
            row.unavailable
                ? L(
                    "keybinding.desktop_away.axhint",
                    "Not connected right now."
                )
                : ""
        )
    }

    /// The name with the query's match in bold.
    private var label: AttributedString {
        var text = AttributedString(row.label)
        guard
            let range = ShortcutsSheet.matchRange(of: match, in: row.label),
            let lower = AttributedString.Index(range.lowerBound, within: text),
            let upper = AttributedString.Index(range.upperBound, within: text)
        else { return text }
        text[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return text
    }

    @ViewBuilder private var leadingGlyph: some View {
        if let glyph = row.glyph {
            Text(glyph)
                .font(
                    Font(
                        AppFont.font(size: 14)
                            ?? .systemFont(ofSize: 14)
                    )
                )
                .frame(width: 16, height: 16)
        } else if row.pocketMark {
            // Vectors, drawn at the row's own size (#2446).
            Image(
                nsImage: PocketMark.mark.image(
                    size: 16,
                    ink: .secondaryLabelColor
                )
            )
            .frame(width: 16, height: 16)
        } else if row.ownApp {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 16, height: 16)
        } else if let bundleID = row.bundleID {
            Image(
                nsImage: AppIconCache.shared.icon(
                    forBundleID: bundleID
                )
            )
            .resizable()
            .frame(width: 16, height: 16)
        } else if let icon = row.icon, !icon.isEmpty {
            IconGlyphLabel(icon: icon)
                .foregroundStyle(.secondary)
        } else {
            Color.clear
        }
    }
}
