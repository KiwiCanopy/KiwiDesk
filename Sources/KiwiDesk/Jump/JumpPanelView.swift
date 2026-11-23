import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub, the key panel (#1875, #2265): a search field, then a
/// side (#2229) — the ranked windows with the hidden apps below
/// them, or the layout tiles — and a footer of the scope's keys.
/// Native like the shortcuts panel — system font, untinted glass.
struct JumpPanelView: View {
    @ObservedObject var model: JumpModel
    /// This opening, which the entrance and the fade out read.
    let presence: PanelPresence
    /// The panel's least width on its screen, from the controller:
    /// a compact side's, and the field row's there (#3570).
    let width: CGFloat
    @FocusState private var fieldFocused: Bool
    @Environment(\.kiwiDeskReduceMotion)
    private var reduceMotion

    /// The key panels' scale (#2229 ▸ shared panel style): the
    /// field row's width (#3570).
    static let width = JumpPanelRoom.fieldWidth
    static let fieldHeight: CGFloat = 44
    /// The scope switch's cross-fade; the refit waits it out.
    static let scopeFade: TimeInterval = 0.12
    static let headerHeight: CGFloat = 26
    /// The field row's inset at each end of the panel, the same as a
    /// row's and the Shortcuts sheet's (#3570 ▸ Amendment 4).
    static let fieldInset = KeyPanelStyle.selectionInset + JumpRowView.padding
    static let listPadding: CGFloat = 6

    var body: some View {
        // The product name around the side's, so a side announces
        // "KiwiHub, window switcher" (#2265).
        VStack(spacing: 0) { side }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(JumpScope.panelName)
            // The side cross-fades as one stack; the field row moves
            // only when the window's frame does, which the refit
            // changes after this fade (#3570).
            .animation(
                reduceMotion
                    ? nil : .easeInOut(duration: Self.scopeFade),
                value: model.scope
            )
            // minHeight 0: a side taller than the window overflows
            // down, never centred up past the top (#3570).
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            .panelContentFade(presence)
            // The side's own width, which the window glides to on ⇥;
            // the field row rides the window's edges, so it moves
            // only with the frame (#3570 ▸ Amendment 4).
            .frame(
                minWidth: width,
                idealWidth: max(model.sideWidth, width),
                maxWidth: .infinity
            )
            .tint(SettingsTheme.accent)
            .panelGlassChrome(
                in: KeyPanelStyle.shape,
                glass: panelGlass,
                fallback: AnyShapeStyle(.regularMaterial)
            )
            .panelEntrance(presence)
    }

    /// The live settings' panel glass (#2604).
    var panelGlass: PanelGlass { PanelGlass(settings: model.settings) }

    private var side: some View {
        VStack(spacing: 0) {
            field
            namingCaption
            PanelDivider()
            // The side keeps its own width but lays out in the
            // window's, so the field row spans the window as it is,
            // never the side's width ahead of the glide (#3570).
            scopeContent.frame(minWidth: 0, maxWidth: .infinity)
            PanelDivider()
            footer
        }
        // The side's own name, which its shortcut row shows (#2245).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.scope.panelName)
    }

    private var field: some View {
        // The glyph's frame matches the row icon's, so the field
        // text and the row titles share one leading edge.
        HStack(spacing: JumpRowView.spacing) {
            Image(systemName: model.isNaming ? "plus" : "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: JumpRowView.iconSize)
                .accessibilityHidden(true)
            TextField(
                "",
                text: Binding(
                    get: { model.query },
                    set: { model.query = $0 }
                ),
                // The field shows only the typing; the selection is
                // the row or tile below (#2246).
                // The panel's measured ink, never the system's faint
                // placeholder grey, which vanishes on light glass.
                prompt: Text(fieldName).foregroundStyle(.secondary)
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .tint(SettingsTheme.accent)
            .focused($fieldFocused)
            .accessibilityLabel(fieldName)
            .accessibilityHint(namingLine ?? "")
            JumpScopeSwitch(model: model)
        }
        // The glyph keeps the row icons' leading edge, and the first
        // column's: the selection's inset plus the row's own padding.
        // The row spans the panel, the switch at its trailing edge.
        .padding(.horizontal, Self.fieldInset)
        .frame(maxWidth: .infinity)
        .frame(height: Self.fieldHeight)
        .onAppear { fieldFocused = true }
        .onChange(of: model.fieldFocusRequests) { fieldFocused = true }
        // A click on the switch may take the focus back; on ⇥ the
        // field already has it, so the write changes nothing and the
        // caret stays.
        .onChange(of: model.scope) { fieldFocused = true }
        .onChange(of: model.fieldSelectAllRequests) { selectFieldText() }
    }

    /// The pre-filled name is selected, so typing replaces it. The
    /// field editor selects a turn later, once the field holds
    /// the new text.
    private func selectFieldText() {
        fieldFocused = true
        // The panel's own field editor, never whatever responds.
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
        }
    }

    /// One scope at a time, cross-faded in place, each at its own
    /// side's width, centred: the window's edges glide to it, and no
    /// side is laid out at another's width meanwhile (#3570).
    @ViewBuilder private var scopeContent: some View {
        ZStack(alignment: .top) {
            if model.scope == .windows {
                VStack(spacing: 0) {
                    // Under the field, which never moves (#2246);
                    // the panel grows down to take it (#3168).
                    if model.list.stripShown {
                        JumpStripView(model: model)
                    }
                    results
                }
                .frame(width: model.sideWidth(for: .windows))
                .transition(.opacity)
            } else if model.scope == .shortcuts, let sheet = model.shortcuts {
                JumpShortcutsView(
                    sheet: sheet,
                    scroll: model.sheetScroll,
                    plan: model.shortcutColumns,
                    maxHeight: model.sheetCap,
                    fades: true
                )
                .frame(width: model.sideWidth(for: .shortcuts))
                .transition(.opacity)
            } else if model.scope == .desktops, let state = model.desktops {
                DesktopsSideView(
                    state: state,
                    icons: model.desktopIcons,
                    onPlace: {
                        model.clickPlace(
                            $0,
                            count: $1,
                            modifiers: $2,
                            opens: $3
                        )
                    },
                    onWindow: {
                        model.clickWindow($0, in: $1, count: $2, modifiers: $3)
                    },
                    onMore: { model.clickMore($0, forward: $1) },
                    onDrop: { model.dropWindows($0, on: $1) },
                    onSettings: { model.handle(.settings, repeated: false) },
                    pointer: DesktopsPointer(
                        hover: model.hover,
                        onHover: {
                            model.hoverDesktops(
                                $0,
                                pointer: model.currentPointer()
                            )
                        },
                        onHoverEnd: { model.endHover($0) }
                    )
                )
                .environment(\.desktopsSwell, model.desktopsSwell)
                .frame(width: model.sideWidth(for: .desktops))
                .transition(.opacity)
            } else if let view = model.view {
                JumpViewSide(
                    list: view,
                    settings: model.settings,
                    commandHeld: model.commandHeld,
                    hover: model.hover,
                    onApply: { model.clickItem($0) },
                    onHover: {
                        model.hoverItem($0, pointer: model.currentPointer())
                    },
                    onHoverEnd: { model.endHover(.item($0)) }
                )
                .frame(width: model.sideWidth(for: .view))
                .transition(.opacity)
            }
        }
    }
}
