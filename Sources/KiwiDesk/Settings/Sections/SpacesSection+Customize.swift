import KiwiDeskCore
import SwiftUI

/// The per-row override cell, the row context menu, the
/// destructive-delete confirmation, and their mutations — split
/// from `SpacesSection.swift` to stay under the line ceiling
/// (#205). The cell summarises the space's saved overrides and
/// pushes the full-pane editor (`SpacesSection+Overrides.swift`);
/// its four-state wording is resolved purely by
/// `OverrideCellState`.
/// The widest override-cell label currently on screen, so every
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

    /// The per-row override cell: a bordered button whose label
    /// summarises the space's saved overrides and whose tap pushes
    /// the full-pane editor (#678 8b, replacing the #205 popover).
    ///
    /// The label is the SUM across every layout
    /// (`overrideFieldCount(for:)`), the scannable "how much custom
    /// config does this space carry" signal; the editor breaks it
    /// into active-layout rows and a dormant drawer. Wording turns
    /// on the space's mode (owner ruling 2026-08-04):
    /// - tiled, N>0 → "N custom"; N==0 → "Customize…";
    /// - Floating, N>0 → a muted "N saved" (the values apply to
    ///   OTHER layouts, not this one) that still opens the editor
    ///   so they stay reachable — "grey, don't hide", §2.7;
    /// - Floating, N==0 → "—", disabled: genuinely no destination.
    /// Withheld entirely while the offer is locked (#678 8c) —
    /// see `SpaceOverrideOffer`, which owns that predicate and
    /// the argument for hiding rather than dimming. Gated HERE,
    /// at the one render site, rather than at the row: the row
    /// would then hold a second copy of the rule, which is the
    /// hand-negated-copy drift `HomeCardOrder.isOffered` exists
    /// to prevent one level up.
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

    /// The cell's text, muted on the Floating-dormant case so it
    /// reads as "saved, not live" rather than an active count.
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
                "Saved for other layouts — switch this space "
                    + "to a tiling layout to use them."
            )
        case .customize, .custom:
            return L(
                "spaces.customize.help",
                "Layout overrides for this space"
            )
        }
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

    // MARK: - Row context menu

    /// Keyboard-reachable equivalents of the drag/badge
    /// affordances (the §3.13 accessibility pattern). Here beside
    /// the delete confirmation it invokes, and the reorder helpers
    /// it is the only caller of, to keep `SpacesSection.swift`
    /// under the line ceiling.
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
