import Combine
import KiwiDeskCore
import SwiftUI

/// The key sequence hint panel (#1871 ▸ hint panel), built from the
/// key panel's Shortcuts side: the leader's name, the breadcrumb,
/// the keys that open more keys marked ›, then the step's end keys
/// as the Shortcuts side files them, and how to leave. It takes no
/// keys of its own: the keyboard tap reads every press. Past
/// KiwiHub's sheet cap only the end keys scroll, under a fade, and
/// the footer says how (#3175).
struct KeySequenceHintView: View {
    let hint: KeySequenceHint
    /// The end keys as the Shortcuts side files them.
    let reference: ShortcutsReference?
    let glass: PanelGlass
    /// KiwiHub's sheet cap on this screen
    /// (`JumpPanelController.sheetCap`).
    var sheetCap: CGFloat = 400
    @ObservedObject var scroll = KeySequenceHintScroll()
    @State private var sheetHeight: CGFloat = 0

    static let width: CGFloat = 360
    /// One branch row and the gap under it: the end keys' cap
    /// leaves room for each (#3175).
    static let branchRowHeight: CGFloat = 26
    static let branchSpacing: CGFloat = 2
    static let corner: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            PanelDivider()
            if !hint.branches.isEmpty {
                VStack(alignment: .leading, spacing: Self.branchSpacing) {
                    ForEach(hint.branches) { key in
                        ShortcutRowView(row: Self.branchRow(key))
                            .frame(height: Self.branchRowHeight)
                    }
                }
            }
            if let reference, !reference.isEmpty {
                JumpShortcutsView(
                    sheet: ShortcutsSheet(reference: reference),
                    scroll: scroll.value,
                    maxHeight: endKeyCap,
                    horizontalInset: 0,
                    verticalInset: 0,
                    fades: false
                )
                .moreBelowFade()
                .onPreferenceChange(SheetHeightKey.self) { sheetHeight = $0 }
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

    /// What the end keys may stand: the cap less the branch rows
    /// above them, which never scroll away.
    var endKeyCap: CGFloat {
        let row = Self.branchRowHeight + Self.branchSpacing
        return max(sheetCap - CGFloat(hint.branches.count) * row, 120)
    }

    var overflows: Bool {
        JumpShortcutsView.overflows(content: sheetHeight, cap: endKeyCap)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if overflows {
                Text(L("key_sequence.hint.scroll", "%1$@ Scroll", "↑↓"))
                Text(verbatim: "·").accessibilityHidden(true)
            }
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

/// The scroll a scroll key asks of the hint panel's sheet (#3175),
/// held across one step's drawing so a press never rebuilds it.
@MainActor
final class KeySequenceHintScroll: ObservableObject {
    @Published var value = SheetScroll()

    func take(_ scroll: KeySequenceScroll) {
        var next = value
        next.serial += 1
        switch scroll {
        case .step(let lines):
            next.lines = lines
            next.pages = 0
        case .page(let pages):
            next.lines = 0
            next.pages = pages
        }
        value = next
    }
}
