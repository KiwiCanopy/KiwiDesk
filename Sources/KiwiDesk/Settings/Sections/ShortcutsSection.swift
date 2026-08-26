import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Shortcuts (#68 §3.6), rendered FROM the settings
/// census (#678 Phase 3): flat intent groups (Focus / Move
/// windows / Size & float / Open applications), then the
/// advanced half — the Layers card and the raw-Lua drawer — with
/// Import in the header where a new user can see it. One
/// recorder can be active at a
/// time (#33), duplicates hard-block with Steal / Go to (#34),
/// and conflict state derives live from the bindings on every
/// render (#35).
///
/// The census owns placement, `ShortcutsRowOrder` owns display
/// order and `ShortcutsFamilyRows` owns the family→rows
/// expansion; `ShortcutsCensusRenderTests` pins all three
/// together. What the census does NOT place is the Inactive
/// shortcuts card: its rows are instances of the `goToSpace` and
/// `moveToSpace` families already censused under Focus and Move
/// windows, surfaced a second time because their space left the
/// list. A census row for it would be a second placement of a
/// setting that already has one, so the card is hand-mounted and
/// the guard states why it holds no census keys.
struct ShortcutsSection: View {
    @ObservedObject var model: SettingsModel
    @State private var selected = KeyLayer.defaultName
    @State private var advancedExpanded = false
    @StateObject private var coordinator =
        RecorderCoordinator()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    actionGroups
                    tail
                }
                .padding(
                    [.horizontal, .bottom],
                    SettingsMetrics.paneInset
                )
                .environment(
                    \.keybindingOverrideBase,
                    model.overrideBaseRows(layer: selected)
                )
                .environment(\.keybindingLayerName, selected)
                .environmentObject(coordinator)
            }
            .onChange(of: coordinator.scrollTarget) {
                _,
                target in
                guard let target else { return }
                withAnimation {
                    proxy.scrollTo(target, anchor: .center)
                }
                coordinator.scrollTarget = nil
            }
        }
        .onAppear {
            ensureSelection()
            // Arm the recorder ⇒ suspend live hotkeys so testing
            // an existing shortcut mid-capture can't fire it
            // (#213). Idempotent across re-appears.
            coordinator.onArmedChange = { [model] armed in
                model.setRecorderArmed(armed)
            }
        }
        // The section stays mounted across reloads and edit-
        // target switches; a vanished layer must never leave
        // `selected` pointing at layers[0] under a phantom
        // header (#68 review M1).
        .onChange(of: model.config.layers.map(\.name)) {
            _,
            _ in
            ensureSelection()
        }
        .onChange(of: model.target) { _, _ in
            ensureSelection()
            coordinator.invalidate()
        }
        .onChange(of: selected) { _, _ in
            coordinator.invalidate()
        }
    }

    // MARK: - Body pieces
    //
    // Split out of `body` rather than nested in it: a single
    // expression holding every group blew the type-checker's
    // budget, which fails on the slower CI runner while
    // compiling fine locally (gui.md's shallow-body rule).

    @ViewBuilder private var header: some View {
        KeybindingConflictBanner(model: model)
        overrideBanner
        ShortcutsHeader(model: model, selected: $selected)
        // The layers that define alternate key sets. It LEADS the
        // area rather than tailing it (owner ruling 2026-08-04):
        // the layer selected here decides what every card below
        // is showing, and a control that reframes the whole page
        // cannot sit under the page it reframes. It withholds
        // itself entirely until earned — see `LayersCard`.
        layersCard
    }

    private var layersCard: some View {
        LayersCard(
            model: model,
            bindings: bindingsBinding,
            selected: $selected,
            expander: expander
        )
    }

    @ViewBuilder private var actionGroups: some View {
        FocusGroup(
            model: model,
            bindings: bindingsBinding,
            expander: expander
        )
        MoveWindowsGroup(
            model: model,
            bindings: bindingsBinding,
            expander: expander
        )
        SizeFloatGroup(
            model: model,
            bindings: bindingsBinding,
            expander: expander
        )
        ApplicationsGroup(model: model, bindings: bindingsBinding)
        GeneralShortcutsGroup(
            model: model,
            bindings: bindingsBinding,
            expander: expander
        )
    }

    @ViewBuilder private var tail: some View {
        // Orphaned space-targeting rows (#92): rendered so "Go
        // to" from a rejected recording can reach the holder —
        // the per-space groups above only render live spaces.
        OrphanedShortcutsGroup(
            model: model,
            bindings: bindingsBinding,
            spaces: model.config.spaces
        )
        // Then the raw-Lua escape hatch, which is `.showMore`
        // outright. `LayersCard` used to sit here and now LEADS
        // the area — see `layersCard` above.
        advancedDrawer
    }

    // MARK: - Override layer (#55 phase 7)

    /// Shown while editing a stored profile: the section
    /// renders the RESOLVED layers; only rows diverging from
    /// the base are saved into the profile's sparse override.
    @ViewBuilder private var overrideBanner: some View {
        if model.editingStoredProfile {
            SettingsSection(
                SettingsCatalog.shortcuts.profileShortcuts
            ) {
                // #123: the live target applies recordings
                // instantly; a stored profile stays staged —
                // say so where the recording happens. But the
                // loaded profile's own overrides re-apply on save
                // (#209), so its banner can't claim "next time
                // it's active" — it IS active.
                if let name = model.editingProfile {
                    Text(overrideBannerText(name))
                        .font(.callout)
                }
                if model.editedProfileOverridesKeys {
                    Label(
                        L(
                            "shortcuts.override.overrides",
                            "This profile overrides base "
                                + "keybindings."
                        ),
                        systemImage:
                            "keyboard.badge.ellipsis"
                    )
                    .font(.callout)
                }
                Text(overrideCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The loaded profile's overrides re-apply the moment you
    /// save (it is the layout on screen); every other stored
    /// profile stays staged until it next loads (#209).
    private func overrideBannerText(_ name: String) -> String {
        if name == model.activeProfile {
            return L(
                "shortcuts.override.staged_loaded",
                "Editing \u{201C}%1$@\u{201D} — shortcuts "
                    + "re-apply as soon as you save.",
                name
            )
        }
        return L(
            "shortcuts.override.staged",
            "Editing \u{201C}%1$@\u{201D} — shortcuts take "
                + "effect the next time this profile is "
                + "active.",
            name
        )
    }

    private var overrideCaption: String {
        L(
            "shortcuts.override.caption",
            "Dimmed rows are inherited from the base "
                + "shortcuts and stay in sync with "
                + "them. Edit a row to override it "
                + "for this profile only; matching "
                + "the base again makes it inherited "
                + "again. Removing an inherited row "
                + "only resets it — to disable a "
                + "combo in this profile, rebind it "
                + "to a no-op action instead."
        )
    }

    // MARK: - Advanced drawer (§3.6.1)

    /// Withheld in Simple (owner ruling 2026-08-04): importing
    /// bindings out of `init.lua` is not a first-week concept,
    /// and a collapsed drawer for it still costs a Simple user a
    /// row of chrome to read past.
    ///
    /// `hasCustomLua` is the FIRST term for the same reason
    /// `layersExist` is on the Layers card: someone whose
    /// `init.lua` already carries bindings must not have the one
    /// surface that explains them hidden by a mode they did not
    /// know they were in.
    private func offersAdvancedDrawer(
        in mode: SettingsMode
    ) -> Bool {
        model.hasCustomLua || mode == .powerUser
    }

    private var offersAdvancedDrawer: Bool {
        offersAdvancedDrawer(in: model.settingsMode)
    }

    @ViewBuilder private var advancedDrawer: some View {
        if offersAdvancedDrawer {
            luaDrawer
        }
    }

    private var luaDrawer: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.luaBindings,
            chrome: .card,
            isExpanded: $advancedExpanded,
            // One predicate at `.simple` (#760): with custom Lua
            // in init.lua the drawer is Simple content, unmarked.
            modeGated: !offersAdvancedDrawer(in: .simple)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(advancedDrawerCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AdvancedLuaGroup(
                    model: model,
                    bindings: bindingsBinding
                )
            }
            .padding(.top, 8)
        }
    }

    private var advancedDrawerCaption: String {
        L(
            "shortcuts.advanced.caption",
            "Bind any Lua to a hotkey. This is the "
                + "power-user escape hatch — the "
                + "groups above cover the built-in "
                + "actions."
        )
    }

    /// The family→rows expansion every group reads. Built once
    /// per render from live state, so the per-space,
    /// per-Desktop and per-layer families expand against what is
    /// actually configured right now.
    ///
    /// The Desktop list is read across EVERY layer's bindings,
    /// not the selected one's: a row that exists only while its
    /// layer is selected would vanish from under the
    /// duplicate-combo block's "Go to", which is free to point
    /// at a row in another layer.
    private var expander: ShortcutsFamilyRows {
        return ShortcutsFamilyRows(
            spaces: model.config.spaces,
            icons: model.config.settings.spaceIcons,
            desktops: KeybindingCatalog.desktopOffer(
                live: model.bindableDesktops,
                bindings: model.config.layers.flatMap(\.bindings)
            ),
            resizeStep: Int(model.config.settings.resizeStep),
            layerNames: model.config.layers.map(\.name),
            currentLayer: selected
        )
    }

    // MARK: - Bindings into the selected layer

    private var layerIndex: Int {
        model.config.layers.firstIndex {
            $0.name == selected
        } ?? 0
    }

    private var bindingsBinding: Binding<[KeyBinding]> {
        Binding(
            get: { model.config.layers[layerIndex].bindings },
            set: {
                model.config.layers[layerIndex].bindings = $0
            }
        )
    }

    /// Falls back to the default layer if the remembered
    /// selection no longer exists (e.g. after a reload).
    private func ensureSelection() {
        if !model.config.layers.contains(
            where: { $0.name == selected }
        ) {
            selected = KeyLayer.defaultName
        }
    }
}
