import KiwiDeskCore
import SwiftUI

/// The key sequence hint panel (#1871 ▸ hint panel), built from the
/// key panel's Shortcuts side: the leader's name, the breadcrumb,
/// the keys that open more keys marked ›, then the step's end keys
/// as the Shortcuts side files them, and how to leave. It takes no
/// keys of its own: the keyboard tap reads every press.
struct KeySequenceHintView: View {
    let hint: KeySequenceHint
    /// The end keys as the Shortcuts side files them.
    let reference: ShortcutsReference?
    let glass: PanelGlass

    static let width: CGFloat = 360
    static let corner: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            PanelDivider()
            if !hint.branches.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(hint.branches) { key in
                        ShortcutRowView(row: Self.branchRow(key))
                            .frame(height: 26)
                    }
                }
            }
            if reference?.isEmpty == false {
                ShortcutsSheetView(reference: reference, needle: "")
            }
            PanelDivider()
            footer
        }
        .padding(14)
        .frame(width: Self.width, alignment: .leading)
        .panelGlassChrome(
            in: RoundedRectangle(
                cornerRadius: Self.corner,
                style: .continuous
            ),
            glass: glass,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hint.title)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(hint.breadcrumb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .accessibilityLabel(hint.spokenBreadcrumb)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L("key_sequence.hint.back", "%1$@ Back", "⌫"))
            Text(verbatim: "·").accessibilityHidden(true)
            Text(L("key_sequence.hint.cancel", "%1$@ Cancel", "Esc"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// A key that opens more keys, as a Shortcuts row led by its
    /// symbol and marked › (#3162).
    static func branchRow(_ key: KeySequenceHint.Key) -> ShortcutRow {
        ShortcutRow(
            id: "branch." + key.chord,
            label: key.name,
            combo: key.chord,
            icon: key.symbol,
            accessoryIcon: "chevron.forward",
            accessoryHelp: L(
                "key_sequence.hint.opens_more",
                "Opens more keys"
            )
        )
    }
}
