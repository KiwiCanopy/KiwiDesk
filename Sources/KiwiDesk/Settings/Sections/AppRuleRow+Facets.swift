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
    ///
    /// Inert through `GreyOut` rather than a bare `.disabled`:
    /// `neutralMenuLabel()` pins this menu's foreground style, and
    /// an explicit foreground on a custom `Menu` label defeats
    /// SwiftUI's own disabled rendering — the value would draw at
    /// full strength beside an empty checkbox, reading as a pin
    /// already in force (ui-designer, 2026-09-22). `GreyOut`'s
    /// explicit opacity cannot be defeated that way, and it
    /// carries the reason.
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
        .modifier(
            GreyOut(active: !isPinned, help: pinHelp)
        )
        .accessibilityLabel(L("app_rules.space", "Space"))
        .accessibilityValue(spaceFacetLabel)
        .accessibilityHint(spaceHint)
    }

    /// Drawn and spoken from ONE expression. While unpinned it
    /// shows the value checking the box would author, so the
    /// reader gets exactly what they were looking at — and in
    /// override mode that is the BASE's Space, so a tombstoned row
    /// says which pin this profile removes.
    var spaceFacetLabel: String {
        model.config.appRules[app]?.raw
            ?? prospectiveSpace?.raw
            ?? L("app_rules.space.none", "No Space")
    }

    /// The Space checking the box would author, nil where there
    /// is none to author.
    var prospectiveSpace: SpaceID? {
        AppRulePin.engagedSpace(
            model.config,
            inherited: overrideBase?[app]
        )
    }

    /// An unpinned menu draws a value the config does not hold, so
    /// the hint says which it is — a dim alone cannot, and without
    /// it VoiceOver reads "Space, work" for an app with no pin.
    private var spaceHint: String {
        isPinned ? "" : pinHelp
    }

    /// Whether this app carries a Space pin right now.
    var isPinned: Bool { model.config.appRules[app] != nil }

    /// What the pin checkbox may do on this row.
    var pinVerdict: AppRulePin.Verdict {
        AppRulePin.verdict(
            // A row whose pattern editor is open floats as far as
            // this question goes, even before its first pattern
            // exists: the user is composing a titled rule, and
            // locking the pin mid-composition would pin an app
            // they are floating.
            floats: floatFacet != .never
                || titlesEditing.wrappedValue,
            isOverride: overrideBase != nil,
            hasSpaces: !model.config.spaces.isEmpty
        )
    }

    /// Pin checkbox (`app_rules.pin`). Auto-checked and locked
    /// while the app tiles normally, free while it floats — the
    /// lock is what makes "a rule must say something" visible
    /// rather than silent — and inert with no Space to pin to,
    /// where a live checkbox would write nothing and pretend.
    var pinCheckbox: some View {
        Toggle(
            L("app_rules.pin", "Pin to a Space"),
            isOn: pinBinding
        )
        .labelsHidden()
        .modifier(
            GreyOut(
                active: pinVerdict != .free,
                help: pinHelp
            )
        )
        .accessibilityLabel(L("app_rules.pin", "Pin to a Space"))
        .accessibilityHint(pinHelp)
    }

    /// Checking engages the row's prospective Space; clearing
    /// removes the pin. The setter refuses unless the verdict is
    /// `.free` so the store cannot be reached past the `GreyOut` —
    /// a keyboard or VoiceOver route to a checkbox is not the
    /// mouse's.
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { isPinned },
            set: { wanted in
                guard pinVerdict == .free else { return }
                model.config.appRules[app] =
                    wanted ? prospectiveSpace : nil
            }
        )
    }

    /// One sentence per state, because a dim is not a sentence and
    /// this one has to answer "why can't I un-pin this?" where the
    /// reader tries it. The always-visible card caption carries
    /// the rule itself; this is the per-state half.
    private var pinHelp: String {
        if pinVerdict == .unavailable {
            return L(
                "app_rules.pin.no_spaces",
                "This profile has no Spaces to pin an app to yet."
            )
        }
        if overrideBase != nil, !isPinned {
            return L(
                "app_rules.pin.tombstone",
                "This profile removes the pin the base rules set."
            )
        }
        if pinVerdict == .locked {
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
                Button(titledLabel) { openTitles() }
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(L("app_rules.float", "Float"))
        .accessibilityValue(floatLabel)
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

    /// An open pattern editor reads as the titled value whatever
    /// the store currently holds, because that is the rule being
    /// composed — including while the bare float rule is still
    /// there, which `openTitles` deliberately leaves alone.
    private var floatLabel: String {
        if titlesEditing.wrappedValue { return restingTitledLabel }
        switch floatFacet {
        case .never: return neverLabel
        case .all: return allLabel
        case .titled: return restingTitledLabel
        }
    }

    // MARK: - Mutations (GUI assembles the colon syntax)

    /// Tiling requires a pin, so dropping the float rule engages
    /// one where the row has none — the one visible consequence
    /// that keeps every row a live rule. Asked of the verdict, so
    /// the write and the checkbox cannot disagree about the two
    /// exceptions.
    private func setNever() {
        // Refused rather than stranding the row: with no Space to
        // pin to, clearing the float rule would leave an app with
        // no stored rule at all, and the list — derived from the
        // store since #1022 retired `draftApps` — would drop the
        // row out from under the user.
        guard pinVerdict != .unavailable || isPinned else {
            return
        }
        clearFloatRules()
        if !isPinned, overrideBase == nil,
            let space = prospectiveSpace
        {
            model.config.appRules[app] = space
        }
    }

    /// Opens the pattern editor WITHOUT clearing the float rule.
    ///
    /// The clear used to happen here, and it deleted the row: a
    /// float-only row's bare rule is its only stored rule, so
    /// removing it dropped the app out of `AppRulesSection.apps`
    /// mid-composition (architect + ui-designer review,
    /// 2026-09-22). Nothing needs it anyway —
    /// `AppRuleTitledEditor.addPattern` drops the bare rule as the
    /// first pattern lands, which is the moment the row genuinely
    /// stops floating everything.
    private func openTitles() {
        titlesEditing.wrappedValue = true
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
