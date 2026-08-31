import KiwiDeskCore
import SwiftUI

/// Shortcut reference row display (`ShortcutRow`).
struct ShortcutRowView: View {
    let row: ShortcutRow

    var body: some View {
        HStack(spacing: 8) {
            leadingGlyph
                .frame(width: 20, height: 20)
            Text(row.label)
                .font(
                    row.monospaced
                        ? .system(.callout, design: .monospaced)
                        : .callout
                )
                .lineLimit(1)
                .truncationMode(.tail)
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
        }
        .help(row.monospaced ? row.label : "")
        // Same 0.55 the editor's rows dim to, so one concept
        // looks like itself on both surfaces — an undimmed
        // detached-Desktop row implies a key that does nothing.
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

    @ViewBuilder private var leadingGlyph: some View {
        if let glyph = row.glyph {
            // #294 App Font ligature, following the panel's text
            // color; fixed slot width keeps the label indent
            // uniform.
            Text(glyph)
                .font(
                    Font(
                        AppFont.font(size: 14)
                            ?? .systemFont(ofSize: 14)
                    )
                )
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

/// Titled subgroup container for shortcut rows (`ShortcutSubgroup`).
struct ShortcutSubgroupView: View {
    let subgroup: ShortcutSubgroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subgroup.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(subgroup.rows) { ShortcutRowView(row: $0) }
        }
    }
}

/// Band section header view.
struct ShortcutsBandHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Divider()
        }
    }
}

/// Two-column balanced shortcut controls band.
struct ControlsBand: View {
    let subgroups: [ShortcutSubgroup]

    var body: some View {
        let split = Self.balance(subgroups)
        HStack(alignment: .top, spacing: 32) {
            column(split.left)
            if split.right.isEmpty {
                Color.clear.frame(maxWidth: .infinity)
            } else {
                column(split.right)
            }
        }
    }

    private func column(
        _ groups: [ShortcutSubgroup]
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { ShortcutSubgroupView(subgroup: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Balances subgroups across two columns by cumulative row count.
    static func balance(
        _ groups: [ShortcutSubgroup]
    ) -> (left: [ShortcutSubgroup], right: [ShortcutSubgroup]) {
        var left: [ShortcutSubgroup] = []
        var right: [ShortcutSubgroup] = []
        var leftHeight = 0
        var rightHeight = 0
        for group in groups {
            let height = group.rows.count + 2
            if leftHeight <= rightHeight {
                left.append(group)
                leftHeight += height
            } else {
                right.append(group)
                rightHeight += height
            }
        }
        return (left, right)
    }
}

/// Grid band for application-specific shortcuts.
struct AppsBand: View {
    let rows: [ShortcutRow]

    var body: some View {
        let pairs = stride(from: 0, to: rows.count, by: 2).map {
            Array(rows[$0..<min($0 + 2, rows.count)])
        }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(pairs.enumerated()), id: \.offset) {
                _,
                pair in
                HStack(alignment: .top, spacing: 32) {
                    ForEach(pair) { row in
                        ShortcutRowView(row: row)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }
                    if pair.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
