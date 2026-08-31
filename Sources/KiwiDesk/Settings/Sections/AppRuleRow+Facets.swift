import KiwiDeskCore
import SwiftUI

/// Facet dropdown menus and mutations within `AppRuleRow`'s
/// sentence. The values are VERB PHRASES — each completes the
/// sentence it sits in. Each menu carries the facet's old label
/// as its accessibility label, which also keeps
/// `app_rules.space` / `app_rules.float` authored at a call site
/// the key scanner can see, or they are pruned from every locale.
extension AppRuleRow {
    /// Space assignment dropdown menu (`app_rules.space`, #678 Phase 4,
    /// turn 20a rule 3).
    var spaceMenu: some View {
        return Menu {
            Button(L("app_rules.automatic", "Automatic")) {
                model.config.appRules[app] = nil
            }
            Divider()
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) {
                    model.config.appRules[app] = space
                }
            }
        } label: {
            menuLabel(spaceFacetLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(L("app_rules.space", "Space"))
        .accessibilityValue(spaceFacetLabel)
    }

    /// Spoken and rendered space assignment label.
    var spaceFacetLabel: String {
        model.config.appRules[app]?.raw
            ?? L(
                "app_rules.space.anywhere",
                "whichever Space you open it in"
            )
    }

    /// Float behavior dropdown menu (`app_rules.float`, #68).
    var floatMenu: some View {
        Menu {
            Button(neverLabel) { setNever() }
            Button(allLabel) { setAll() }
            Button(titledLabel) {
                // Re-selecting the active choice must not wipe
                // the pattern list (#68 review m3).
                if floatFacet != .titled {
                    setNever()
                }
                titlesEditing.wrappedValue = true
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(L("app_rules.float", "Float"))
        .accessibilityValue(floatLabel)
        .help(
            // The catalog string carries Markdown for the `?`
            // popover; a tooltip renders none, so strip the
            // markers as `HelpButton` does for its own fallback.
            floatHelp.replacingOccurrences(of: "**", with: "")
        )
    }

    /// Inline menu label with disclosure chevron (`ProfileEditTargetMenu`).
    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var neverLabel: String {
        L("app_rules.float.never", "tiles normally")
    }

    private var allLabel: String {
        L("app_rules.float.all_windows", "floats")
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "floats when titled…")
    }

    /// The resting VALUE drops the menu item's ellipsis: an
    /// ellipsis promises further UI — right on a choice opening
    /// the pattern editor, wrong inside a statement.
    private var restingTitledLabel: String {
        L("app_rules.float.titled.resting", "floats when titled")
    }

    private var floatLabel: String {
        switch floatFacet {
        case .never:
            return titlesEditing.wrappedValue
                ? restingTitledLabel : neverLabel
        case .all: return allLabel
        case .titled: return restingTitledLabel
        }
    }

    /// Tooltip explanation for float facet (#260, `AppRuleTitledEditor`).
    private var floatHelp: String {
        L(
            "app_rules.float.help",
            "Floating takes this app's matching windows out of "
                + "tiling: each keeps its last position and size "
                + "and stays above the tiled windows, instead of "
                + "snapping into one Space's grid.\n\nThis is "
                + "per-app floating — not the **Floating** layout "
                + "mode, which floats every window in a Space."
        )
    }

    // MARK: - Mutations (GUI assembles the colon syntax)

    private func setNever() {
        titlesEditing.wrappedValue = false
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
    }

    private func setAll() {
        setNever()
        model.config.floatRules.append(app)
    }
}
