import AppKit
import KiwiDeskCore
import SwiftUI

/// One app's rules (#68 §3.11): icon + name, then the Space
/// facet (Automatic or a pinned space) and the Float facet
/// (Never / All windows / Windows titled… with pattern chips).
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// The base rules while editing a stored profile (#109):
    /// non-nil switches the row into override mode — the Space
    /// facet edits this profile's sparse override (inherited
    /// rows dimmed, like the Shortcuts tab), the Float facet
    /// is app-wide and renders disabled (grey out, not hide).
    let overrideBase: [String: SpaceID]?
    let onDelete: () -> Void
    /// Keeps the titled editor visible while it has no
    /// patterns yet (an empty pattern set stores nothing).
    @State private var editingTitles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            facetRows
            if floatFacet == .titled || editingTitles {
                AppRuleTitledEditor(
                    model: model,
                    app: app,
                    editingTitles: $editingTitles
                )
                .padding(.leading, 90)
                // App-wide, like the facet menu above.
                .disabled(overrideBase != nil)
            }
        }
        .opacity(inherited ? 0.55 : 1)
    }

    /// Whether the row is inherited unchanged from the base —
    /// the Space facet matches the base's (or both are absent).
    /// Always false during live editing, mirroring
    /// `KeyBinding.isInherited(from:)`.
    private var inherited: Bool {
        guard let base = overrideBase else { return false }
        return model.config.appRules[app] == base[app]
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            appIcon
            Text(app).fontWeight(.medium)
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(
                overrideBase == nil
                    ? L(
                        "app_rules.remove_all.help",
                        "Remove all rules for this app"
                    )
                    : L(
                        "app_rules.remove_override.help",
                        "Un-pin this app in this profile "
                            + "(float rules stay app-wide)"
                    )
            )
        }
    }

    @ViewBuilder private var appIcon: some View {
        if let path = appPath {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: path
                )
            )
            .resizable()
            .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    private var appPath: String? {
        [
            "/Applications/\(app).app",
            "/System/Applications/\(app).app",
        ].first {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    // MARK: - Facets

    private var facetRows: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Text(L("app_rules.space", "Space"))
                    .foregroundStyle(.secondary)
                spaceMenu
            }
            HStack(spacing: 6) {
                Text(L("app_rules.float", "Float"))
                    .foregroundStyle(.secondary)
                floatPicker
            }
            // Float rules have no per-profile tier (#109):
            // grey out, never hide (the #171 convention).
            .disabled(overrideBase != nil)
            .help(
                overrideBase == nil
                    ? ""
                    : L(
                        "app_rules.float.app_wide.help",
                        "Float rules are app-wide — edit "
                            + "them while editing the live "
                            + "configuration."
                    )
            )
            Spacer()
        }
        .font(.callout)
        .padding(.leading, 28)
    }

    /// `app_rules[app]`; Automatic deletes the entry.
    private var spaceMenu: some View {
        let automatic = L("app_rules.automatic", "Automatic")
        return Menu {
            Button(automatic) {
                model.config.appRules[app] = nil
            }
            Divider()
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) {
                    model.config.appRules[app] = space
                }
            }
        } label: {
            menuLabel(
                model.config.appRules[app]?.raw ?? automatic
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var floatFacet: FloatFacet {
        FloatFacet.current(
            model.config.floatRules,
            app: app
        )
    }

    private var floatPicker: some View {
        Menu {
            Button(L("app_rules.float.never", "Never")) {
                setNever()
            }
            Button(
                L("app_rules.float.all_windows", "All windows")
            ) { setAll() }
            Button(titledLabel) {
                // Re-selecting the active choice must not
                // wipe the pattern list (#68 review m3).
                if floatFacet != .titled {
                    setNever()
                }
                editingTitles = true
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    /// The borderless-menu signature (`ProfileEditTargetMenu`):
    /// a trailing chevron on the label so a bare-text menu
    /// still reads as "this opens a menu".
    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "Windows titled…")
    }

    private var floatLabel: String {
        switch floatFacet {
        case .never:
            return editingTitles
                ? titledLabel
                : L("app_rules.float.never", "Never")
        case .all:
            return L("app_rules.float.all_windows", "All windows")
        case .titled: return titledLabel
        }
    }

    // MARK: - Mutations (GUI assembles the colon syntax)

    private func setNever() {
        editingTitles = false
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
    }

    private func setAll() {
        setNever()
        model.config.floatRules.append(app)
    }
}
