import KiwiDeskCore
import SwiftUI

/// The dashboard shell: a profile/state banner, the five
/// configuration tabs (or the raw Lua editor when the file
/// holds foreign code), and a save/revert footer.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            ProfileSyncBanner(model: model)
            Divider()
            content
            Divider()
            SettingsFooter(model: model)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    @ViewBuilder private var content: some View {
        if model.editingLua {
            LuaEditorTab(model: model)
        } else {
            VStack(spacing: 0) {
                if model.hasCustomLua {
                    CustomLuaBanner()
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                    Divider()
                }
                TabView {
                    PresetsTab(model: model)
                        .tabItem {
                            Label(
                                "Presets",
                                systemImage: "square.grid.2x2"
                            )
                        }
                    GeneralTab(model: model)
                        .tabItem {
                            Label(
                                "General",
                                systemImage: "gearshape"
                            )
                        }
                    CanvasTab(model: model)
                        .tabItem {
                            Label(
                                "Canvas",
                                systemImage:
                                    "rectangle.on.rectangle"
                            )
                        }
                    SpacesTab(model: model)
                        .tabItem {
                            Label(
                                "Spaces",
                                systemImage:
                                    "rectangle.split.3x1"
                            )
                        }
                    AppBarTab(model: model)
                        .tabItem {
                            Label(
                                "App Bar",
                                systemImage: "menubar.rectangle"
                            )
                        }
                    // App Rules are global, not part of any
                    // profile (Model A) — hidden while editing
                    // a stored profile (#18). Shortcuts stay
                    // visible there in OVERRIDE mode: the
                    // profile's sparse keybinding tier (#55
                    // phase 7).
                    if !model.editingStoredProfile {
                        AppRulesTab(model: model)
                            .tabItem {
                                Label(
                                    "App Rules",
                                    systemImage: "app.badge"
                                )
                            }
                    }
                    KeybindingsTab(model: model)
                        .tabItem {
                            Label(
                                "Shortcuts",
                                systemImage: "keyboard"
                            )
                        }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
        }
    }
}

/// Save / revert footer with the unsaved-changes indicator. When
/// the raw Lua editor is forced (init.lua holds custom code), it
/// also hosts the "parse into the visual editor" action so it
/// shares the row with Revert / Save.
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingAdopt = false
    @State private var showAdoptHelp = false
    @State private var helpHovering = false
    @State private var namingNewProfile = false
    @State private var newProfileName = ""

    /// A muted, darker green so the action reads as inviting
    /// without shouting over the standard Save button.
    private let adoptGreen = Color(
        red: 0.16,
        green: 0.45,
        blue: 0.24
    )

    var body: some View {
        HStack(spacing: 8) {
            if model.forcedLuaEditor {
                adoptButton
                helpButton
            }
            if model.isDirty {
                Label(
                    "Unsaved changes",
                    systemImage: "pencil.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            Spacer()
            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)
            if model.editingLua {
                Button("Save") { model.saveLuaSource() }
                    .keyboardShortcut("s")
                    .disabled(!model.isDirty)
            } else if model.editingStoredProfile {
                editProfileSaveButton
            } else {
                updateButton
                saveAsNewButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .confirmationDialog(
            "Adopt this config into the visual editor?",
            isPresented: $confirmingAdopt,
            titleVisibility: .visible
        ) {
            Button("Adopt") { model.adoptIntoGui() }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Save as new profile",
            isPresented: $namingNewProfile
        ) {
            TextField("Profile name", text: $newProfileName)
            Button("Save") {
                model.saveAsNewProfile(named: newProfileName)
                newProfileName = ""
            }
            .disabled(newProfileName.trimmed.isEmpty)
            Button("Cancel", role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(
                "The new profile carries the current tiling "
                    + "and the connected monitor set."
            )
        }
    }

    /// Update "<profile>": enabled only when a profile is
    /// active, its screen count matches, and something changed.
    @ViewBuilder private var updateButton: some View {
        if let name = model.activeProfile {
            Button("Update \u{201C}\(name)\u{201D}") {
                model.updateActiveProfile()
            }
            .keyboardShortcut("s")
            .disabled(
                !model.updateEnabled
                    || !(model.isDirty || model.profileDirty)
            )
            .help(model.updateHint ?? "")
        }
    }

    private var saveAsNewButton: some View {
        Button("Save as new…") { namingNewProfile = true }
            .buttonStyle(.borderedProminent)
    }

    /// Stored-profile edit mode (#18): write the edits into that
    /// profile's JSON without switching the live layout.
    @ViewBuilder private var editProfileSaveButton: some View {
        let name = model.editingProfile ?? ""
        Button("Save to \u{201C}\(name)\u{201D}") {
            model.saveEditedProfile()
        }
        .keyboardShortcut("s")
        .buttonStyle(.borderedProminent)
        .disabled(!model.isDirty)
    }

    private var adoptButton: some View {
        Button {
            confirmingAdopt = true
        } label: {
            Label(
                "Parse into Visual Editor…",
                systemImage: "wand.and.stars"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(adoptGreen)
    }

    private var helpButton: some View {
        Image(systemName: "questionmark.circle")
            .imageScale(.large)
            .foregroundStyle(
                helpHovering ? Color.accentColor : .secondary
            )
            .animation(.easeInOut(duration: 0.15), value: helpHovering)
            .onHover { hovering in
                helpHovering = hovering
                showAdoptHelp = hovering
            }
            .help("What happens to my current code?")
            .popover(isPresented: $showAdoptHelp, arrowEdge: .top) {
                Text(
                    "Nothing is lost: your current code isn't "
                        + "deleted, it's kept as a commented-out "
                        + "backup in init.lua. Gaps, layouts, "
                        + "rules, and keybindings are imported; "
                        + "a shortcut that can't be read back "
                        + "stays in the backup — re-add it in "
                        + "the Shortcuts tab."
                )
                .font(.callout)
                .frame(width: 300)
                .padding()
            }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
