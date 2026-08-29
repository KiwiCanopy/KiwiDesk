import KiwiDeskCore
import SwiftUI

/// The Shortcuts header: the Import button — placed here,
/// visible without scrolling, where the new user it serves can
/// find it — and a label naming which layer the groups below
/// bind into.
///
/// The layer strip itself lives in the Layers card
/// (`LayerStripEditor`), which is where the census places it.
struct ShortcutsHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var importedNote = false
    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                editingLabel
                Spacer()
                // Import only offers itself when init.lua has
                // custom Lua (the same condition as the
                // banner): with nothing custom in the file
                // there is nothing it could find, and inside
                // the visual editor active foreign binds have
                // already forced the raw-Lua fallback anyway.
                if model.hasCustomLua,
                    !model.editingStoredProfile
                {
                    importButton
                }
                // Gated, not permanent: it appears only when
                // KiwiDesk actually has defaults this install
                // lacks. That makes its PRESENCE the news #1096
                // exists to deliver, instead of a destructive-
                // sounding button standing over every new user's
                // shortcut list for a condition they do not have
                // — the same argument that keeps Import absent
                // until init.lua holds something to adopt.
                if model.hasDefaultsToRestore {
                    resetButton
                }
            }
            if importedNote {
                // `groupHeading` is the green-emphasis TEXT
                // token (the diff rows' precedent) — `.green`
                // lifts in dark while the app's greens do not,
                // and full-strength `accent` on words reads
                // clickable (dark pass).
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.groupHeading)
            }
        }
    }

    /// Which layer the rows below belong to — a LABEL, not a
    /// control, and shown only once a second layer exists.
    ///
    /// The census tiers the layer strip `.showMore`, so the strip
    /// itself now lives in the Layers card rather than the header
    /// (owner ruling: the census is the area's authority). But
    /// every group below binds into the SELECTED layer, and an
    /// editor that does not say what it is editing is a trap the
    /// moment a second layer exists — so the header keeps the
    /// fact and gives up the control. With only `default` there
    /// is nothing to disambiguate and it stays silent.
    @ViewBuilder private var editingLabel: some View {
        if model.config.layers.count > 1 {
            Text(
                L(
                    "shortcuts.editing_layer",
                    "Editing the \u{201C}%1$@\u{201D} layer",
                    selected
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Restore defaults (#1096)

    /// Takes up the shipped defaults, which the seed alone
    /// cannot deliver: it fires only into an empty config, so
    /// an existing install never sees an improved default.
    ///
    /// Disabled rather than hidden off the default layer
    /// (`gui.md` — grey, don't hide), because the seed only ever
    /// authored that one; `.help` says which, so the greying
    /// explains itself.
    ///
    /// Danger is signalled by the confirmation's destructive
    /// role, never a resting red button — the house convention
    /// `GeneralSection+Reset` states.
    private var resetButton: some View {
        Button {
            confirmingReset = true
        } label: {
            Label(
                L(
                    "shortcuts.restore_defaults",
                    "Restore Defaults…"
                ),
                systemImage: "arrow.counterclockwise"
            )
        }
        .settingsActionButton()
        .controlSize(.small)
        .disabled(selected != KeyLayer.defaultName)
        .help(resetHelp)
        .confirmationDialog(
            L(
                "shortcuts.restore_defaults.title",
                "Restore the default shortcuts?"
            ),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                model.resetShortcutsToDefaults()
            } label: {
                Text(
                    L(
                        "shortcuts.restore_defaults.confirm",
                        "Restore Defaults"
                    )
                )
            }
            Button(role: .cancel) {
            } label: {
                // NOT `discard.cancel` — that key reads
                // "Continue editing" in seven locales, and
                // nothing is being edited on this dialog.
                // `GeneralSection+Reset` hit the same trap.
                Text(
                    L("spaces.delete_confirm.cancel", "Cancel")
                )
            }
        } message: {
            Text(resetMessage)
        }
    }

    /// Names the COUNT it would discard rather than asking "are
    /// you sure": a number is what makes the choice informed,
    /// and it is zero for the common case of an untouched layer,
    /// where the sentence says so instead of threatening.
    /// Leads with the GAIN and treats the loss as the caveat:
    /// the question a user has here is "what do I get, and what
    /// does it cost", and an earlier draft answered only the
    /// second half — telling the very population this exists for
    /// (people who customised their defaults) that their
    /// shortcuts were about to be deleted, when what was
    /// happening was the thing they had asked for.
    ///
    /// The loss count is now true collateral only: a shortcut of
    /// the user's OWN removed because a default reclaims its
    /// key. A default they merely moved is not a loss — the verb
    /// comes back on its shipped chord, which is the point.
    private var resetMessage: String {
        let restored = model.shortcutsTheResetWouldRestore
        let lost = model.shortcutsTheResetWouldDiscard
        if lost == 0 {
            return L(
                "shortcuts.restore_defaults.message_clean",
                "Nothing of yours is lost — review the changes "
                    + "below, then %1$@. Shortcuts restored: %2$d",
                L("footer.save", "Save"),
                restored
            )
        }
        // `footer.save` is INTERPOLATED, not quoted (#818): the
        // neighbour playing this same beat already does it, and
        // German's Save button is "Sichern" — a translator
        // reaching for the obvious word would name a button that
        // does not exist. Quoted, that mirror drifts silently in
        // a language nobody reviewing `footer.save` reads.
        //
        // The counts are separated by "·", never a comma: six
        // locales use the comma as a DECIMAL separator, so
        // "restored: 12, and" starts parsing as a number. The
        // corpus already settled this in `behavior.quit.summary`.
        return L(
            "shortcuts.restore_defaults.message",
            "Your own shortcuts are kept, except any that use a "
                + "key the defaults need. Review the changes "
                + "below, then %1$@. Shortcuts restored: %2$d · "
                + "your own that are lost: %3$d",
            L("footer.save", "Save"),
            restored,
            lost
        )
    }

    private var resetHelp: String {
        selected == KeyLayer.defaultName
            ? L(
                "shortcuts.restore_defaults.help",
                "Puts back the shortcuts KiwiDesk provides, "
                    + "including ones it has added since you "
                    + "installed it. Shortcuts you made yourself "
                    + "are kept."
            )
            : L(
                "shortcuts.restore_defaults.help_other_layer",
                "Only the default layer has defaults to restore "
                    + "— this one is yours."
            )
    }

    // MARK: - Import (#4)

    private var importButton: some View {
        Button {
            model.importCurrentShortcuts()
            if !model.config.layers.contains(where: {
                $0.name == selected
            }) {
                selected = KeyLayer.defaultName
            }
            importedNote = true
        } label: {
            Label(
                L(
                    "shortcuts.import",
                    "Import from init.lua…"
                ),
                systemImage: "square.and.arrow.down"
            )
        }
        // Explicitly sealed rather than left to the default
        // style: the two render alike, but only a named style
        // is visible to the guard keeping the accent off button
        // labels.
        .settingsActionButton()
        // Small: it sits inline beside the layer chips and
        // must not read as a peer tab.
        .controlSize(.small)
        .help(importHelp)
    }

    /// The destination group is INTERPOLATED from the key that
    /// labels it rather than named as text (#818): this sentence
    /// said "lands in Advanced" while the drawer had read "Lua
    /// bindings" since #68, so every locale had faithfully
    /// translated a group name no locale draws.
    private var importHelp: String {
        L(
            "shortcuts.import.help",
            "Reads the shortcuts active in init.lua and adds "
                + "them here, matching each combo. Known "
                + "actions sort into the groups below; "
                + "anything else lands in \u{201C}%1$@\u{201D}. "
                + "Review, then Save.",
            L("shortcuts.advanced.title", "Lua bindings")
        )
    }

    private var importedNoteText: String {
        L(
            "shortcuts.imported_note",
            "Shortcuts imported — review below, then %1$@.",
            L("footer.save", "Save")
        )
    }
}
