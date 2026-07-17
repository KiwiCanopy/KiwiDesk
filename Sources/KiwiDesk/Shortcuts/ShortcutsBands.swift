import KiwiDeskCore
import SwiftUI

/// One reference row: an optional leading glyph, the label, and
/// the right-aligned key-combo glyphs. Pure signage — no hover
/// highlight, no pointer cursor, no button chrome — so it never
/// reads as an editable control (rebinding lives in Settings).
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
            Text(row.combo)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        // Custom rows carry the full Lua as a tooltip since the
        // label truncates.
        .help(row.monospaced ? row.label : "")
    }

    @ViewBuilder private var leadingGlyph: some View {
        if let bundleID = row.bundleID {
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
        }
    }
}

/// A titled subgroup inside the Controls band (Focus, Move
/// Windows, …): a secondary subheading over its rows.
struct ShortcutSubgroupView: View {
    let subgroup: ShortcutSubgroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subgroup.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(subgroup.rows) { ShortcutRowView(row: $0) }
        }
    }
}

/// A band header: a bold signage label over a hairline divider —
/// deliberately lighter than a boxed settings card, which would
/// imply the rows are actionable.
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

/// The Controls band: subgroups bin-packed across two
/// height-balanced columns, never splitting a subgroup — so a
/// row's position is a function of what it is, not of how many
/// other rows exist (glance-lookup stays stable).
struct ControlsBand: View {
    let subgroups: [ShortcutSubgroup]

    var body: some View {
        let split = Self.balance(subgroups)
        HStack(alignment: .top, spacing: 32) {
            column(split.left)
            if !split.right.isEmpty {
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

    /// Greedy height balance over whole subgroups: each is placed
    /// in the currently-shorter column. Height ≈ rows + the
    /// subheading.
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

/// The Apps band: uniform icon + name + combo tiles in a two-
/// column grid, alphabetical — free wrap is fine here since there
/// is no subgroup structure to protect.
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
