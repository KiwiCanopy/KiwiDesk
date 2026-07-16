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
    /// non-nil switches the row into override mode. Each facet
    /// independently dims while it still matches its base.
    let overrideBase: [String: SpaceID]?
    let overrideFloatBase: [String]?
    /// Whether the row is a session draft (added this session,
    /// no stored facet yet) — deleting one always works, it
    /// removes the draft itself.
    let isDraft: Bool
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
                .opacity(floatInherited ? 0.55 : 1)
            }
        }
    }

    private var spaceInherited: Bool {
        guard let base = overrideBase, !isDraft else {
            return false
        }
        return model.config.appRules[app] == base[app]
    }

    private var floatInherited: Bool {
        guard let base = overrideFloatBase, !isDraft else {
            return false
        }
        return Set(FloatFacet.rules(base, app: app))
            == Set(
                FloatFacet.rules(
                    model.config.floatRules,
                    app: app
                )
            )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            appIcon
            Text(KeybindingCatalog.displayName(forBundleID: app))
                .fontWeight(.medium)
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(
                overrideBase != nil
                    && model.config.appRules[app] == nil
                    && floatFacet == .never
                    && !isDraft
            )
            .help(
                overrideBase == nil
                    ? L(
                        "app_rules.remove_all.help",
                        "Remove all rules for this app"
                    )
                    : L(
                        "app_rules.remove_override.help",
                        "Remove this profile's effective space "
                            + "and float rules for this app"
                    )
            )
        }
    }

    @ViewBuilder private var appIcon: some View {
        if let url = appURL {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: url.path
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

    /// The installed bundle for this rule's app, resolved from
    /// its bundle id — nil (dashed placeholder) when the app
    /// isn't installed on this machine.
    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app
        )
    }

    // MARK: - Facets

    private var facetRows: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Text(L("app_rules.space", "Space"))
                    .foregroundStyle(.secondary)
                spaceMenu
                    .frame(
                        width: SettingsMetrics.facetControlColumn,
                        alignment: .leading
                    )
            }
            .opacity(spaceInherited ? 0.55 : 1)
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(L("app_rules.float", "Float"))
                        .foregroundStyle(.secondary)
                    HelpButton(
                        explanation: floatHelp,
                        subject: L("app_rules.float", "Float")
                    )
                }
                floatPicker
                    .frame(
                        width: SettingsMetrics.facetControlColumn,
                        alignment: .leading
                    )
            }
            .opacity(floatInherited ? 0.55 : 1)
            Spacer()
        }
        .font(.callout)
        .padding(.leading, 28)
    }

    /// Optional "why" depth for the Float facet (#260): what
    /// floating a window actually does, plus the per-app-vs-
    /// layout-mode disambiguation (same English word, two
    /// mechanisms). Must-know scope stays in the section caption;
    /// the titled-pattern mechanics stay in `AppRuleTitledEditor`
    /// — don't restate them here or the two drift.
    private var floatHelp: String {
        L(
            "app_rules.float.help",
            "Floating takes this app's matching windows out of "
                + "tiling: each keeps its last position and size "
                + "and appears on every space, instead of living "
                + "in one space's grid.\n\nThis is per-app "
                + "floating — not the **Floating** layout mode, "
                + "which floats every window in a space."
        )
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
    }

    /// The borderless-menu signature (`ProfileEditTargetMenu`):
    /// a trailing chevron on the label so a bare-text menu
    /// still reads as "this opens a menu". `lineLimit(1)` lets a
    /// long value truncate inside the fixed facet slot (#260)
    /// instead of overflowing it — the menus dropped `.fixedSize`
    /// so the enclosing `.frame(width:)` constrains them.
    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
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
