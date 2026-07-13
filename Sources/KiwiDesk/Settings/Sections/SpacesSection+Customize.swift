import KiwiDeskCore
import SwiftUI

/// The per-row Customize popover, the destructive-delete
/// confirmation, and their mutations — split from
/// `SpacesSection.swift` to stay under the line ceiling (#205).
/// Moving the override editor into a popover decouples its
/// height from the pane scroll: the space list stays short and
/// scannable, and the floating surface is its own card, instead
/// of an inline block pushing every row below it down.
extension SpacesSection {
    /// The Customize button anchors a bounded popover holding
    /// the space's override rows. `customizing` is a single slot,
    /// so only one popover is ever open (the accordion the issue
    /// asked for falls out for free).
    func customizeButton(_ space: SpaceID) -> some View {
        Button {
            customizing = (customizing == space) ? nil : space
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(.borderless)
        .help(L("spaces.customize.help", "Customize this space"))
        .popover(
            isPresented: Binding(
                get: { customizing == space },
                set: { if !$0 { customizing = nil } }
            ),
            arrowEdge: .bottom
        ) {
            overridePopover(space)
        }
    }

    /// The override editor floats at a fixed width with its own
    /// scroll, so even the tallest mode's field set can't grow
    /// the pane — it scrolls inside the popover instead.
    private func overridePopover(_ space: SpaceID) -> some View {
        ScrollView {
            SpaceOverrideRows(model: model, space: space)
                .padding(14)
        }
        .frame(width: 360)
        .frame(maxHeight: 380)
    }

    // MARK: - Destructive delete

    /// Deleting a space that only holds a name and a mode is
    /// cheap and reversible (re-add it), so it goes straight
    /// through. One that carries overrides — a pin, the Main
    /// role, the fallback flag, or per-space settings the user
    /// may have just tuned in the popover — asks first, since
    /// the delete cascades through all of them.
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
        L("spaces.delete_confirm.title", "Delete this space?")
    }

    var deleteConfirmMessage: String {
        L(
            "spaces.delete_confirm.message",
            "This space has customized settings — its "
                + "layout overrides, monitor pin, and any "
                + "Main or Fallback role are removed too. You "
                + "can add the space back, but not its "
                + "settings."
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
}
