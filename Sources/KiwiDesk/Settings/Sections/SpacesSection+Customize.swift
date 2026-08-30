import KiwiDeskCore
import SwiftUI

/// Per-row override cell, context menu, and delete confirmation dialogs (#205,
/// #678).
struct OverridesButtonWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}

extension SpacesSection {
    /// Destructive row action in trailing danger slot.
    func deleteButton(_ space: SpaceID) -> some View {
        Button {
            requestRemove(space)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(
            L("spaces.delete.help", "Delete Space")
        )
    }

    /// Per-row override cell button opening full-pane editor (#678 8b, owner
    /// ruling 2026-08-04).
    @ViewBuilder func customizeButton(
        _ space: SpaceID
    ) -> some View {
        if SpaceOverrideOffer.isOffered(
            mode: model.settingsMode,
            settings: model.config.settings,
            spaces: model.config.spaces
        ) {
            offeredCustomizeButton(space)
        }
    }

    private func offeredCustomizeButton(
        _ space: SpaceID
    ) -> some View {
        let count = model.config.settings.overrideFieldCount(
            for: space
        )
        let isFloating =
            (model.config.spaceModes[space] ?? .bsp) == .floating
        let state = OverrideCellState.resolve(
            count: count,
            isFloating: isFloating
        )
        return Button {
            model.nav.spaceOverridesFocus = space
        } label: {
            overrideCellLabel(state)
        }
        .settingsActionButton()
        .controlSize(.large)
        .fixedSize()
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OverridesButtonWidth.self,
                    value: proxy.size.width
                )
            }
        )
        .frame(
            width: overridesButtonWidth > 0
                ? overridesButtonWidth : nil,
            alignment: .center
        )
        .disabled(state.isInert)
        .help(overrideCellHelp(state))
        .accessibilityLabel(
            L(
                "spaces.overrides.a11y",
                "Layout overrides for %1$@, %2$d saved",
                space.raw,
                count
            )
        )
    }

    @ViewBuilder
    private func overrideCellLabel(
        _ state: OverrideCellState
    ) -> some View {
        switch state {
        case .inert:
            Text(verbatim: "—")
        case .saved(let count):
            Text(L("spaces.overrides.saved", "%1$d saved", count))
                .foregroundStyle(.secondary)
        case .customize:
            Text(L("spaces.overrides.customize", "Customize…"))
        case .custom(let count):
            Text(L("spaces.overrides.custom", "%1$d custom", count))
        }
    }

    private func overrideCellHelp(_ state: OverrideCellState) -> String {
        switch state {
        case .inert:
            return L(
                "spaces.overrides.floating.help",
                "Floating has no layout overrides."
            )
        case .saved:
            return L(
                "spaces.overrides.saved.help",
                "Saved for other layouts — switch this Space "
                    + "to a tiling layout to use them."
            )
        case .customize, .custom:
            return L(
                "spaces.customize.help",
                "Layout overrides for this Space"
            )
        }
    }

    /// Prompts confirmation if space carries overrides before removing.
    func requestRemove(_ space: SpaceID) {
        if model.config.carriesOverrides(space) {
            pendingDelete = space
        } else {
            removeSpace(space)
        }
    }

    var deleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    var deleteConfirmTitle: String {
        L("spaces.delete_confirm.title", "Delete this Space?")
    }

    /// Confirmation message with interpolated role names (#818).
    var deleteConfirmMessage: String {
        L(
            "spaces.delete_confirm.message",
            "This Space has customized settings — its "
                + "layout overrides, monitor pin, and any "
                + "\u{201C}%1$@\u{201D} or \u{201C}%2$@\u{201D} "
                + "role are removed too. You "
                + "can add the Space back, but not its "
                + "settings.",
            L("monitor_card.follows_main", "Follows main display"),
            L("spaces.fallback_badge", "Fallback")
        )
    }

    @ViewBuilder
    func deleteConfirmActions(_ space: SpaceID) -> some View {
        Button(
            L("spaces.delete_confirm.delete", "Delete"),
            role: .destructive
        ) {
            removeSpace(space)
        }
        Button(
            L("spaces.delete_confirm.cancel", "Cancel"),
            role: .cancel
        ) {}
    }

    /// Confirmation binding for resetting all layout overrides on space
    /// (#290).
    var resetAllConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingResetAll != nil },
            set: { if !$0 { pendingResetAll = nil } }
        )
    }

    var resetAllConfirmTitle: String {
        L(
            "space_override.reset_all_confirm.title",
            "Reset all layout overrides?"
        )
    }

    var resetAllConfirmMessage: String {
        L(
            "space_override.reset_all_confirm.message",
            "This clears every layout's saved overrides for "
                + "this Space, not just the current one. This "
                + "can't be undone."
        )
    }

    @ViewBuilder
    func resetAllConfirmActions(_ space: SpaceID) -> some View {
        Button(
            L("space_override.reset_all_confirm.action", "Reset All"),
            role: .destructive
        ) {
            model.config.settings.resetAllLayoutOverrides(
                for: space
            )
        }
        Button(
            L("spaces.delete_confirm.cancel", "Cancel"),
            role: .cancel
        ) {}
    }

    /// Context menu actions for space row reordering and role assignments.
    @ViewBuilder
    func contextActions(_ space: SpaceID) -> some View {
        if model.config.fallbackSpace == space {
            Button(
                L("spaces.context.clear_fallback", "Clear Fallback")
            ) {
                model.config.fallbackSpace = nil
            }
        } else {
            Button(
                L("spaces.context.make_fallback", "Make Fallback")
            ) {
                model.config.fallbackSpace = space
            }
        }
        Divider()
        Button(L("spaces.context.move_up", "Move Up")) {
            nudge(space, by: -1)
        }
        .disabled(index(of: space) == 0)
        Button(L("spaces.context.move_down", "Move Down")) {
            nudge(space, by: 1)
        }
        .disabled(
            index(of: space)
                == model.config.spaces.count - 1
        )
        Divider()
        Button(
            L("spaces.context.delete", "Delete"),
            role: .destructive
        ) {
            requestRemove(space)
        }
    }

    private func index(of space: SpaceID) -> Int {
        model.config.spaces.firstIndex(of: space) ?? 0
    }

    private func nudge(_ space: SpaceID, by delta: Int) {
        let from = index(of: space)
        let to = from + delta
        guard model.config.spaces.indices.contains(to) else {
            return
        }
        model.config.spaces.swapAt(from, to)
    }
}
