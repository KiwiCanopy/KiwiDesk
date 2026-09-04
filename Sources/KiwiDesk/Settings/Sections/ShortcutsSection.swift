import KiwiDeskCore
import SwiftUI

/// Shortcuts settings section, rendered FROM the census (#68,
/// #678): the census owns placement, `ShortcutsRowOrder` display
/// order, `ShortcutsFamilyRows` the family→rows expansion —
/// `ShortcutsCensusRenderTests` pins all three. The Inactive
/// shortcuts card is deliberately NOT censused: its rows are
/// instances of families already placed, so the card is
/// hand-mounted and the guard states why it holds no keys.
/// Single active recorder (#33), duplicate blocking (#34), live
/// conflict detection (#35).
struct ShortcutsSection: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @ObservedObject var model: SettingsModel
    @State private var advancedExpanded = false
    @StateObject private var coordinator =
        RecorderCoordinator()

    /// The selected layer lives on `nav` rather than here
    /// (#1127): the live preview panel is this section's
    /// sibling, so it can only learn the layer from the model.
    /// Cleared per visit by `SettingsNavigation.resetSurfaces()`.
    private var selection: Binding<String> {
        Binding(
            get: { selected },
            set: { model.nav.shortcutsLayer = $0 }
        )
    }

    private var selected: String {
        model.nav.shortcutsLayer ?? KeyLayer.defaultName
    }

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
                // One live read per section render (#1105), so
                // every row narrates the same verdict (#1126).
                .environment(
                    \.disabledSystemShortcuts,
                    model.disabledSystemShortcuts()
                )
                .environmentObject(coordinator)
            }
            .onChange(of: coordinator.scrollTarget) {
                _,
                target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(target, anchor: .center)
                }
                coordinator.scrollTarget = nil
            }
        }
        .onAppear {
            ensureSelection()
            // Suspend hotkeys while capturing to avoid trigger during edit
            // (#213).
            coordinator.onArmedChange = { [model] armed in
                model.setRecorderArmed(armed)
            }
        }
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

    @ViewBuilder private var header: some View {
        KeybindingConflictBanner(model: model)
        overrideBanner
        ShortcutsHeader(model: model, selected: selection)
        // LayersCard leads section (owner ruling 2026-08-04).
        layersCard
    }

    private var layersCard: some View {
        LayersCard(
            model: model,
            bindings: bindingsBinding,
            selected: selection,
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
        // Orphaned space-targeting rows (#92).
        OrphanedShortcutsGroup(
            model: model,
            bindings: bindingsBinding,
            spaces: model.config.spaces
        )
        advancedDrawer
    }

    // Profile keybinding overrides (#55, #123, #209).
    @ViewBuilder private var overrideBanner: some View {
        if model.editingStoredProfile {
            SettingsSection(
                SettingsCatalog.shortcuts.profileShortcuts
            ) {
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

    /// Re-application notice when editing active vs stored profile (#209).
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

    /// Withheld in Simple (owner ruling 2026-08-04): importing
    /// bindings out of init.lua is not a first-week concept.
    /// `hasCustomLua` is the FIRST term for `layersExist`'s
    /// reason: someone whose init.lua already carries bindings
    /// must not have the one surface that explains them hidden by
    /// a mode they did not know they were in.
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
            // present the drawer is Simple content, unmarked.
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

    /// Family-to-rows expansion built from live state. The
    /// Desktop list reads EVERY layer's bindings, not the
    /// selected one's: a row existing only while its layer is
    /// selected would vanish from under the duplicate block's
    /// "Go to", which may point into another layer.
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
            model.nav.shortcutsLayer = KeyLayer.defaultName
        }
    }
}
