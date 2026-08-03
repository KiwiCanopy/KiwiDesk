import KiwiDeskCore
import SwiftUI

/// The two menus inside the rule sentence, and the mutations
/// behind them (see `AppRuleRow` for the sentence itself).
///
/// **The values are verb phrases** — "floats", "tiles
/// normally", "floats when titled…" — because each one has to
/// complete the sentence it sits in. The nouns they replaced
/// ("All windows", "Never") were correct beside a "Float:"
/// label and read as nothing at all inside a statement.
///
/// Each menu carries the facet's old label as its
/// **accessibility label**. That is not a consolation prize for
/// the deleted labels: a sentence gives a screen reader no name
/// for the control, and the settings census names this row by
/// the same key, so `app_rules.space` / `app_rules.float` have
/// to stay authored at a call site the key scanner can see or
/// they are pruned from every locale.
extension AppRuleRow {
    /// `app_rules[app]`; the unset state deletes the entry.
    ///
    /// Its label is a phrase, not "Automatic". The unset state
    /// is the one every float-only rule shows — "Finder opens in
    /// Automatic and floats" is the DEFAULT reading of this row,
    /// and a noun there leaves the sentence half-converted. The
    /// menu ITEM keeps a noun, because a menu is a list of
    /// choices rather than a sentence.
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
            menuLabel(
                model.config.appRules[app]?.raw
                    ?? L(
                        "app_rules.space.anywhere",
                        "whichever space you open it in"
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(L("app_rules.space", "Space"))
    }

    var floatMenu: some View {
        Menu {
            Button(neverLabel) { setNever() }
            Button(allLabel) { setAll() }
            Button(titledLabel) {
                // Re-selecting the active choice must not
                // wipe the pattern list (#68 review m3).
                if floatFacet != .titled {
                    setNever()
                }
                titlesEditing.wrappedValue = true
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(L("app_rules.float", "Float"))
        .help(
            // The catalog string carries Markdown emphasis for
            // the `?` popover that renders it richly. A tooltip
            // renders none, so the markers would ship literally
            // in all eleven locales — `HelpButton` strips them
            // for its own hover fallback and this must too.
            floatHelp.replacingOccurrences(of: "**", with: "")
        )
    }

    /// The borderless-menu signature (`ProfileEditTargetMenu`):
    /// a trailing chevron on the label so a bare-text menu
    /// still reads as "this opens a menu". Inside a sentence
    /// the menu hugs its value (`fixedSize`) rather than
    /// filling a fixed facet column — the words on either side
    /// are what it has to line up with now, not a grid.
    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Float facet vocabulary

    private var neverLabel: String {
        L("app_rules.float.never", "tiles normally")
    }

    private var allLabel: String {
        L("app_rules.float.all_windows", "floats")
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "floats when titled…")
    }

    /// The resting VALUE drops the ellipsis the menu item
    /// carries: an ellipsis promises further UI, which is right
    /// on a choice that opens the pattern editor and wrong on a
    /// statement — "Spotify opens in media and floats when
    /// titled…" reads as a sentence that was cut off.
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

    /// Optional "why" depth for the Float facet (#260): what
    /// floating a window actually does, plus the per-app-vs-
    /// layout-mode disambiguation (same English word, two
    /// mechanisms). Must-know scope stays in the section
    /// caption; the titled-pattern mechanics stay in
    /// `AppRuleTitledEditor` — don't restate them here or the
    /// two drift.
    ///
    /// A hover string rather than the `?` affordance it used to
    /// be: a `?` button inside the sentence would break the
    /// sentence, which is the one thing this row is for.
    private var floatHelp: String {
        L(
            "app_rules.float.help",
            "Floating takes this app's matching windows out of "
                + "tiling: each keeps its last position and size "
                + "and stays above the tiled windows, instead of "
                + "snapping into one space's grid.\n\nThis is "
                + "per-app floating — not the **Floating** layout "
                + "mode, which floats every window in a space."
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
