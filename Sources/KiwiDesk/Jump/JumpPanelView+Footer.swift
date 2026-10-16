import KiwiDeskCore
import SwiftUI

/// KiwiHub's footer row: the side's buttons at its edges and its
/// key hints between them.
extension JumpPanelView {
    var footer: some View {
        JumpFooterRow(
            footer: JumpFooter(
                scope: model.scope,
                overflows: footerOverflows,
                modifiers: model.heldModifiers,
                hasSelection: model.hasSelection,
                quickCount: model.viewQuickCount
            ),
            leading: { footerLeading },
            trailing: { footerTrailing }
        )
    }

    /// Whether the side runs past what it shows, which the footer's
    /// scroll cue says.
    private var footerOverflows: Bool {
        switch model.scope {
        case .windows:
            return listOverflows
        case .shortcuts:
            return JumpShortcutsView.overflows(
                content: sheetHeight,
                cap: model.sheetCap
            )
        case .view:
            return false
        }
    }

    @ViewBuilder private var footerLeading: some View {
        switch model.scope {
        case .windows:
            EmptyView()
        case .shortcuts:
            if let name = model.shortcuts?.reference?.layerName,
                name != KeyLayer.defaultName
            {
                JumpLayerLabel(name: name)
            }
        case .view:
            KeyPanelChordButton(
                title: ViewPickText.settings(
                    model.view?.selection?.line ?? .layout
                ),
                chord: "⌘,"
            ) { model.handle(.settings) }
        }
    }

    @ViewBuilder private var footerTrailing: some View {
        switch model.scope {
        case .windows:
            EmptyView()
        case .shortcuts:
            KeyPanelChordButton(
                title: L(
                    "shortcuts.panel.edit_in_settings",
                    "Edit in Settings…"
                ),
                chord: "⌘,"
            ) { model.handle(.settings) }
        case .view:
            if let layout = model.view?.layout,
                let profile = layout.profile
            {
                KeyPanelChordButton(
                    title: LayoutPickText.keep(profile),
                    chord: "⌘S",
                    hint: layout.keepArmed ? nil : LayoutPickText.keepSaved
                ) { model.handle(.keep) }
                .disabled(!layout.keepArmed)
            }
        }
    }
}

/// The footer row's shape: the side's controls are sized first
/// and the hints take what is left, shedding from the end where a
/// locale's controls leave them too little room. The controls are
/// prioritised rather than fixed, so the layer chip still
/// truncates at its own cap.
struct JumpFooterRow<Leading: View, Trailing: View>: View {
    let footer: JumpFooter
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    static var spacing: CGFloat { 12 }
    static var inset: CGFloat { KeyPanelStyle.selectionInset + 10 }

    var body: some View {
        HStack(spacing: Self.spacing) {
            leading.layoutPriority(1)
            footer
            trailing.layoutPriority(1)
        }
        .padding(.horizontal, Self.inset)
    }
}

/// The Shortcuts side's active layer, where it is not the default.
struct JumpLayerLabel: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(SettingsTheme.accent.opacity(0.2))
            )
            .frame(maxWidth: 280, alignment: .leading)
    }
}
