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
                quickCount: model.viewQuickCount,
                turnsOff: model.view?.selectionTurnsOff ?? false,
                naming: model.isNaming
            ),
            carriesControls: model.scope != .windows,
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
            // The scroll cue reads first, beside the active layer.
            HStack(spacing: 8) {
                if let name = model.shortcuts?.reference?.layerName,
                    name != KeyLayer.defaultName
                {
                    JumpLayerLabel(name: name)
                }
                if footerOverflows,
                    let cue = JumpFooter.scrollHint(for: .shortcuts)
                {
                    JumpScrollCue(text: cue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .view:
            let line = model.view?.selection?.line ?? .layout
            KeyPanelChordButton(
                title: ViewPickText.settings(line),
                chord: "⌘,",
                symbol: ViewPickText.destination(line).symbol,
                reserves: ViewPickText.settingsLabels
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
                    title: LayoutPickText.keep,
                    chord: "⌘S",
                    hint: layout.keepArmed
                        ? LayoutPickText.keepHint(profile)
                        : LayoutPickText.keepSaved,
                    help: LayoutPickText.keepHint(profile)
                ) { model.handle(.keep) }
                .disabled(!layout.keepArmed)
            }
        }
    }
}

/// The footer row's shape: the side's controls at its edges and the
/// hints on the panel's midline (`JumpFooterMidline`), shedding from
/// the end where a locale's controls leave them too little room.
struct JumpFooterRow<Leading: View, Trailing: View>: View {
    let footer: JumpFooter
    /// Whether a side draws a button here: View and Shortcuts always
    /// do, Windows never.
    let carriesControls: Bool
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    static var spacing: CGFloat { 12 }
    static var inset: CGFloat { KeyPanelStyle.selectionInset + 10 }

    /// A row of buttons takes room around them; a row of captions
    /// alone stays as low as the captions.
    static func height(carriesControls: Bool) -> CGFloat {
        carriesControls ? 31 : 28
    }

    var body: some View {
        // Each side is one subview even where it draws nothing.
        JumpFooterMidline(spacing: Self.spacing) {
            ZStack { leading }
            footer
            ZStack { trailing }
        }
        .padding(.horizontal, Self.inset)
        .frame(height: Self.height(carriesControls: carriesControls))
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
