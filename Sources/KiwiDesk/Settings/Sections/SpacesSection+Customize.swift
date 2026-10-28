import KiwiDeskCore
import SwiftUI

/// Per-row Customize button, context menu, and delete confirmation
/// dialogs (#205, #678, #2674).
extension SpacesSection {
    /// Destructive row action in trailing danger slot.
    func deleteButton(_ space: SpaceID) -> some View {
        SpaceDeleteButton { requestRemove(space) }
    }

    /// Per-row Customize button opening the full-pane editor, on
    /// every row (#2674).
    func customizeButton(_ space: SpaceID) -> some View {
        SpaceCustomizeButton(model: model, space: space) {
            model.nav.spaceOverridesFocus = space
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

    var deleteConfirmTitle: String { SpaceDeleteWording.title }

    /// Confirmation message with interpolated role names (#818).
    var deleteConfirmMessage: String {
        SpaceDeleteWording.overridesMessage
    }

    @ViewBuilder
    func deleteConfirmActions(_ space: SpaceID) -> some View {
        Button(SpaceDeleteWording.delete, role: .destructive) {
            removeSpace(space)
        }
        Button(SpaceDeleteWording.cancel, role: .cancel) {}
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
        // The editor's second door, beside the row's Customize
        // button (#2654, #2674).
        Button(L("spaces.overrides.customize", "Customize…")) {
            model.nav.spaceOverridesFocus = space
        }
        Divider()
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
