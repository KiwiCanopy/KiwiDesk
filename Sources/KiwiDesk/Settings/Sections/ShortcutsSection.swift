import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Shortcuts (#68 §3.6): a layer strip (chips, "+"
/// popover), flat intent groups (Focus / Move windows / Size &
/// Float / Switch layers / Open applications), the raw-Lua rows
/// demoted to a collapsed Advanced drawer, and Import moved to
/// the header where a new user can see it. One recorder can be
/// active at a time (#33), duplicates hard-block with Steal /
/// Go to (#34), and conflict state derives live from the
/// bindings on every render (#35).
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
                    KeybindingConflictBanner(model: model)
                    overrideBanner
                    ShortcutsHeader(
                        model: model,
                        selected: $selected
                    )
                    // Right under the strip that defines the
                    // layers — the switch shortcuts belong
                    // beside their definition, not buried
                    // below the action groups.
                    if model.config.layers.count > 1 {
                        SwitchLayersGroup(
                            model: model,
                            bindings: bindingsBinding,
                            layerNames: model.config.layers.map(
                                \.name
                            ),
                            current: selected
                        )
                    }
                    FocusGroup(
                        model: model,
                        bindings: bindingsBinding,
                        spaces: model.config.spaces
                    )
                    MoveWindowsGroup(
                        model: model,
                        bindings: bindingsBinding,
                        spaces: model.config.spaces
                    )
                    SizeFloatGroup(
                        model: model,
                        bindings: bindingsBinding
                    )
                    ApplicationsGroup(
                        model: model,
                        bindings: bindingsBinding
                    )
                    GeneralShortcutsGroup(
                        model: model,
                        bindings: bindingsBinding
                    )
                    // Orphaned space-targeting rows (#92):
                    // rendered so "Go to" from a rejected
                    // recording can reach the holder — the
                    // per-space groups above only render
                    // live spaces.
                    OrphanedShortcutsGroup(
                        model: model,
                        bindings: bindingsBinding,
                        spaces: model.config.spaces
                    )
                    advancedDrawer
                }
                .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
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

    private var advancedDrawer: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.luaBindings,
            chrome: .card,
            isExpanded: $advancedExpanded
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

    // MARK: - Bindings into the selected layer

    private var modeIndex: Int {
        model.config.layers.firstIndex {
            $0.name == selected
        } ?? 0
    }

    private var bindingsBinding: Binding<[KeyBinding]> {
        Binding(
            get: { model.config.layers[modeIndex].bindings },
            set: {
                model.config.layers[modeIndex].bindings = $0
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
