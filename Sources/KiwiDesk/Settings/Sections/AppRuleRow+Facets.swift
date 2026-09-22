import KiwiDeskCore
import SwiftUI

/// Facet controls and mutations within `AppRuleRow` (#1022).
///
/// The float values are NOUNS naming the scope that floats — the
/// set of this app's windows the rule takes out of tiling. They
/// were verb phrases while the row was a sentence they had to
/// complete; beside a label they are read as values, and a value
/// is a noun. Deliberately not "Floating": that is
/// `layout.floating.name`, the Floating layout MODE, and a facet
/// value spelled like a layout mode reproduces the two-wordings
/// defect one surface over.
///
/// Each menu carries the facet's census label as its
/// accessibility name, which also keeps `app_rules.space` /
/// `app_rules.float` authored at a call site the key scanner can
/// see, or they are pruned from every locale. Naming a `Menu`
/// REPLACES the choice VoiceOver would read, so each gives the
/// value back explicitly.
extension AppRuleRow {
    /// Space assignment dropdown (`app_rules.space`). There is no
    /// unset item: the absence of a pin is rendered as the
    /// absence of a pin — the checkbox beside this menu — never
    /// as a value named after it (#1022 retired `Automatic`).
    var spaceMenu: some View {
        Menu {
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
        .disabled(!isPinned || model.config.spaces.isEmpty)
        .accessibilityLabel(L("app_rules.space", "Space"))
        .accessibilityValue(spaceFacetLabel)
    }

    /// Drawn and spoken from ONE expression. While unpinned it
    /// shows the value checking the box would author, so the
    /// reader gets exactly what they were looking at.
    var spaceFacetLabel: String {
        model.config.appRules[app]?.raw
            ?? AppRulePin.defaultSpace(model.config)?.raw
            ?? ""
    }

    /// Whether this app carries a Space pin right now.
    var isPinned: Bool { model.config.appRules[app] != nil }

    /// Whether tiling holds this row's pin engaged.
    ///
    /// A row whose pattern editor is open floats as far as this
    /// question goes, even before its first pattern exists: the
    /// user is composing a titled rule, and locking the pin
    /// mid-composition would pin an app they are floating.
    var pinIsLocked: Bool {
        AppRulePin.isLocked(
            floats: floatFacet != .never
                || titlesEditing.wrappedValue,
            isOverride: overrideBase != nil,
            hasSpaces: !model.config.spaces.isEmpty
        )
    }

    /// Pin checkbox (`app_rules.pin`). Auto-checked and locked
    /// while the app tiles normally, free while it floats — the
    /// lock is what makes "a rule must say something" visible
    /// rather than silent, and `GreyOut` carries its reason.
    var pinCheckbox: some View {
        Toggle(
            L("app_rules.pin", "Pin to a Space"),
            isOn: pinBinding
        )
        .labelsHidden()
        .modifier(
            GreyOut(active: pinIsLocked, help: pinHelp)
        )
        .accessibilityLabel(L("app_rules.pin", "Pin to a Space"))
        .accessibilityHint(pinHelp)
    }

    /// Checking engages the designated Space; clearing removes the
    /// pin. The setter refuses while locked so the store cannot be
    /// reached past the `.disabled` — a keyboard or VoiceOver
    /// route to a checkbox is not the mouse's.
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { isPinned },
            set: { wanted in
                guard !pinIsLocked else { return }
                model.config.appRules[app] =
                    wanted
                    ? AppRulePin.defaultSpace(model.config)
                    : nil
            }
        )
    }

    /// One sentence per state, because a dim is not a sentence and
    /// this one has to answer "why can't I un-pin this?" where the
    /// reader tries it. The always-visible card caption carries
    /// the rule itself; this is the per-state half.
    private var pinHelp: String {
        if overrideBase != nil, !isPinned {
            return L(
                "app_rules.pin.tombstone",
                "This profile removes the pin the base rules set."
            )
        }
        if pinIsLocked {
            return L(
                "app_rules.pin.locked",
                "This app doesn't float, so it needs a Space to "
                    + "open in. Unpinning it would leave no rule "
                    + "at all."
            )
        }
        if isPinned {
            return L(
                "app_rules.pin.on",
                "Opens in this Space, whatever Space you are in."
            )
        }
        return L(
            "app_rules.pin.free",
            "Unpinned, this app opens in whichever Space you "
                + "open it in."
        )
    }

    /// Float behavior dropdown (`app_rules.float`, #68). The
    /// titled choice is an OFFER (#1022): withheld in Simple until
    /// some row carries a pattern, and hidden rather than greyed,
    /// per the 2026-08-04 ruling that mode-withheld surface is
    /// absent in this window.
    var floatMenu: some View {
        Menu {
            Button(neverLabel) { setNever() }
            Button(allLabel) { setAll() }
            if offersTitles {
                Button(titledLabel) {
                    // Re-selecting the active choice must not
                    // wipe the pattern list (#68 review m3).
                    // `clearFloatRules`, never `setNever` —
                    // composing a titled rule must not engage the
                    // pin that tiling does.
                    if floatFacet != .titled {
                        clearFloatRules()
                    }
                    titlesEditing.wrappedValue = true
                }
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .accessibilityLabel(L("app_rules.float", "Float"))
        .accessibilityValue(floatLabel)
    }

    /// Asked of the WHOLE list the reader can see — the draft's
    /// rules plus the override base's — never of this row.
    private var offersTitles: Bool {
        AppRuleTitleOffer.isOffered(
            mode: model.settingsMode,
            floatRules: model.config.floatRules
                + (overrideFloatBase ?? [])
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
        L("app_rules.float.never", "No windows")
    }

    private var allLabel: String {
        L("app_rules.float.all_windows", "All windows")
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "Windows by title…")
    }

    /// The resting VALUE drops the menu item's ellipsis: an
    /// ellipsis promises further UI — right on a choice opening
    /// the pattern editor, wrong on a value at rest.
    private var restingTitledLabel: String {
        L("app_rules.float.titled.resting", "Windows by title")
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

    // MARK: - Mutations (GUI assembles the colon syntax)

    /// Tiling requires a pin, so dropping the float rule engages
    /// one where the row has none — the one visible consequence
    /// that keeps every row a live rule. Never in override mode,
    /// where an unpinned tiling row is the tombstone, and never
    /// with no Space to pin to.
    private func setNever() {
        clearFloatRules()
        if !isPinned, overrideBase == nil,
            let space = AppRulePin.defaultSpace(model.config)
        {
            model.config.appRules[app] = space
        }
    }

    /// Drops every float rule for this app and closes the pattern
    /// editor, authoring no pin.
    private func clearFloatRules() {
        titlesEditing.wrappedValue = false
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
    }

    /// Flipping back to floating LEAVES the pin: "floats, and
    /// belongs to work" is a legal rule, the checkbox is right
    /// there to release it, and remembering which gesture
    /// authored a stored value is the session state #1022 deleted.
    private func setAll() {
        clearFloatRules()
        model.config.floatRules.append(app)
    }
}
