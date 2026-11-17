import KiwiDeskCore
import SwiftUI

/// Shortcut reference row display (`ShortcutRow`).
struct ShortcutRowView: View {
    let row: ShortcutRow
    /// The Shortcuts side's query, drawn bold in the name (#2246).
    @Environment(\.shortcutMatch) private var match
    @Environment(\.shortcutColumns) private var columns

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
            if let detail = row.detail ?? pathHit {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 12)
            if let accessory = row.accessoryIcon {
                Image(systemName: accessory)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help(row.accessoryHelp)
            }
            gestureColumn
            chord
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

    /// The badge, then the divider where the row has a gesture; in
    /// a section with a badge column a row without one keeps the
    /// divider's slot (#3380). Outside a section, the badge alone.
    @ViewBuilder private var gestureColumn: some View {
        if let columns {
            if columns.badges {
                ShortcutGestureBadgeView(badges: row.gestures)
                if columns.chords { dividerSlot }
            }
        } else {
            ShortcutGestureBadgeView(badges: row.gestures)
        }
    }

    /// The divider beside a gesture, or its empty slot.
    private var dividerSlot: some View {
        ZStack {
            Color.clear
            if !row.gestures.isEmpty {
                PanelDivider(
                    axis: .vertical,
                    length: ShortcutColumns.dividerLength
                )
            }
        }
        .frame(width: ShortcutColumns.dividerSlot)
        .accessibilityHidden(true)
    }

    /// The chord, right-aligned in the section's widest chord.
    private var chord: some View {
        Text(row.combo)
            .font(.callout)
            .foregroundStyle(.secondary)
            // A sided chord grows; the name truncates first, never
            // the chord (#2601).
            .fixedSize()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ShortcutChordWidthKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .frame(minWidth: columns?.chord ?? 0, alignment: .trailing)
            .accessibilityLabel(row.spokenChord)
            .help(row.spokenHelp)
    }

    /// Which name along a key sequence's path the search matched
    /// (#1871), so a hit never matches text the row does not draw.
    private var pathHit: String? {
        row.matchedPathName.map {
            L("shortcuts.panel.in_sequence", "in %1$@", $0)
        }
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
            // Vectors, drawn at the row's own size (#2446), in the
            // mark's Automatic ink (#2671).
            Image(nsImage: PocketMark.mark.image(size: 16, hex: ""))
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
        } else if let icon = row.icon {
            ShortcutGlyphView(glyph: icon)
                .foregroundStyle(.secondary)
        } else {
            Color.clear
        }
    }
}
