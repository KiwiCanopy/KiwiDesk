import KiwiDeskCore
import SwiftUI

/// The Jump to window panel (#1875): a search field, the ranked
/// windows with the hidden apps below them, and a static footer.
/// Native like the shortcuts panel — system font, untinted glass.
struct JumpPanelView: View {
    @ObservedObject var model: JumpModel
    /// The #1307 switch's keyboard-panel leaf, read by the
    /// controller from the active profile.
    let liquidGlass: Bool
    @FocusState private var fieldFocused: Bool

    static let width: CGFloat = 620
    static let headerHeight: CGFloat = 26
    static let listPadding: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            results
            Divider()
            JumpFooter()
        }
        .frame(width: Self.width)
        .tint(SettingsTheme.accent)
        .glassChrome(
            in: RoundedRectangle(cornerRadius: 12, style: .continuous),
            enabled: liquidGlass,
            variant: .regular,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                "",
                text: Binding(
                    get: { model.query },
                    set: { model.query = $0 }
                ),
                prompt: Text(Self.fieldName)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 22))
            .focused($fieldFocused)
            .accessibilityLabel(Self.fieldName)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { fieldFocused = true }
    }

    static var fieldName: String {
        L("jump.field.label", "Jump to window")
    }

    @ViewBuilder private var results: some View {
        if model.list.results.isEmpty {
            Text(model.emptyText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: JumpRowView.height)
                .padding(.vertical, Self.listPadding)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    rows
                        .padding(.vertical, Self.listPadding)
                        .padding(.horizontal, 6)
                }
                .frame(height: listHeight)
                .onChange(of: model.list.selection) { _, selection in
                    if let selection { proxy.scrollTo(selection) }
                }
            }
        }
    }

    private var rows: some View {
        let list = model.list
        let here = JumpRowText.here(of: list.snapshot)
        return LazyVStack(spacing: 0) {
            ForEach(
                Array(list.results.enumerated()),
                id: \.offset
            ) { index, match in
                if index == list.hiddenStart {
                    hiddenHeader
                }
                JumpRowView(
                    match: match,
                    icon: model.icons[match.entry.pid],
                    isSelected: index == list.selection,
                    number: JumpList.number(ofRow: index),
                    commandHeld: model.commandHeld,
                    shiftHeld: model.shiftHeld,
                    wayHere: match.entry.movesHere ? here : nil
                ) { moveHere in
                    model.onPick(match.entry, moveHere)
                }
                .id(index)
            }
        }
    }

    private var hiddenHeader: some View {
        Text(JumpRowText.hidden)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: Self.headerHeight, alignment: .bottom)
    }

    /// The list's height: what its rows take, up to `rowCap` rows.
    private var listHeight: CGFloat {
        Self.listHeight(
            rows: model.list.results.count,
            hasHeader: model.list.hiddenStart != nil,
            rowCap: model.rowCap
        )
    }

    static func listHeight(
        rows: Int,
        hasHeader: Bool,
        rowCap: Int
    ) -> CGFloat {
        let content =
            CGFloat(rows) * JumpRowView.height
            + (hasHeader ? headerHeight : 0)
        let cap = CGFloat(rowCap) * JumpRowView.height
        return min(content, cap) + 2 * listPadding
    }
}

/// The panel's static key hints — hidden from VoiceOver, whose
/// row actions say the same (#1875 ▸ footer).
private struct JumpFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(L("jump.footer.jump", "%1$@ Jump", "↩"))
            Text(verbatim: "·")
            Text(L("jump.footer.move_here", "%1$@ Move here", "⇧↩"))
            Text(verbatim: "·")
            Text(L("jump.footer.quick", "%1$@ Quick jump", "⌘1–9"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}
