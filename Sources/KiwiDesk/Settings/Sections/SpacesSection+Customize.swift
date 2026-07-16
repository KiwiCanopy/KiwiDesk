import KiwiDeskCore
import SwiftUI

/// The per-row Customize popover, the destructive-delete
/// confirmation, and their mutations — split from
/// `SpacesSection.swift` to stay under the line ceiling (#205).
/// Moving the override editor into a popover decouples its
/// height from the pane scroll: the space list stays short and
/// scannable, and the floating surface is its own card, instead
/// of an inline block pushing every row below it down.
/// The widest Overrides-button label currently on screen, so every
/// row's button locks to one shared column width instead of each
/// hugging its own (variable-count / variable-locale) label —
/// mirrors `SpaceRowFrames` in `SpacesSection+Drag.swift`.
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
    /// Destructive row action, kept behind the divider in the
    /// trailing danger slot. The shared icon affordance supplies
    /// its persistent chip, hover confirmation, and VoiceOver name.
    func deleteButton(_ space: SpaceID) -> some View {
        Button {
            requestRemove(space)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(
            L("spaces.delete.help", "Delete space")
        )
    }

    /// The Customize button anchors a bounded popover holding
    /// the space's override rows. `customizing` is a single slot,
    /// so only one popover is ever open (the accordion the issue
    /// asked for falls out for free).
    func customizeButton(_ space: SpaceID) -> some View {
        let count = model.config.settings.overrideFieldCount(
            for: space
        )
        // Floating carries no active-layout overrides (#290): the
        // button stays visible but disabled, its count still
        // reporting any dormant values so they aren't hidden — the
        // user reaches them by switching the space to a real
        // layout ("grey, don't hide", §2.7).
        let isFloating =
            (model.config.spaceModes[space] ?? .bsp) == .floating
        return Button {
            customizing = (customizing == space) ? nil : space
        } label: {
            // Count in the label, not a colored badge: a
            // parenthetical numeral is the native descriptive
            // form and is perceivable without color (#290). The
            // ellipsis and the count are mutually exclusive — the
            // numeral already signals there is something to open.
            Text(
                count > 0
                    ? L(
                        "spaces.overrides.count",
                        "Overrides (%1$d)",
                        count
                    )
                    : L("spaces.overrides.none", "Overrides…")
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        // Hug the label so the GeometryReader below measures its
        // true (untruncated) width, not a compressed one.
        .fixedSize()
        // Report this row's intrinsic width upward; the list-wide
        // max (measured, never a hardcoded guess, so it survives
        // longer locales) is fed back as every row's column width
        // below. A bigger count or longer label only widens the
        // shared column — it can never truncate one, and every
        // button lines up in a stable column across rows.
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
        .disabled(isFloating)
        .help(
            isFloating
                ? L(
                    "spaces.overrides.floating.help",
                    "Floating has no layout overrides."
                )
                : L(
                    "spaces.customize.help",
                    "Layout overrides for this space"
                )
        )
        .accessibilityLabel(
            L(
                "spaces.overrides.a11y",
                "Layout overrides for %1$@, %2$d saved",
                space.raw,
                count
            )
        )
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
            SpaceOverrideRows(
                model: model,
                space: space,
                pendingResetAll: $pendingResetAll
            )
            .padding(14)
        }
        // 384, not 360: pays back the 22 pt the label column
        // grew (#94 label-adjacent help), so the ratio sliders
        // inside keep their drag travel instead of absorbing
        // the loss on the app's narrowest editing surface.
        .frame(width: 384)
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

    // MARK: - Reset all layout overrides

    /// The only destructive reset that confirms (#290): clearing a
    /// single layout's overrides is one click away from re-adding
    /// them, but wiping every layout's saved values — including the
    /// dormant ones the popover doesn't show — can't be eyeballed
    /// before it happens, so it asks. State lives here (not on the
    /// popover) so the dialog outlives the popover's dismissal,
    /// mirroring `pendingDelete`.
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
                + "this space, not just the current one. This "
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
}
