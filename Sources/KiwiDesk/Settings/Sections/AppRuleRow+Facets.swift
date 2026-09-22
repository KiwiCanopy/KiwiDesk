import KiwiDeskCore
import SwiftUI

/// Facet controls and mutations within `AppRuleRow` (#1022).
///
/// Both facets are STATEMENTS, and the float values state the
/// tiling case positively: "Tiles always", never "Off" or "No
/// windows". A negation makes the reader invert it, which is what
/// sank the first cut — the owner's own reading of it was "float,
/// no windows, pin to a space, work" (owner, on device,
/// 2026-09-22). Deliberately not "Floating", which is
/// `layout.floating.name`, the layout MODE.
///
/// Each menu carries the facet's census label as its
/// accessibility name, which also keeps `app_rules.space` /
/// `app_rules.float` authored at a call site the key scanner can
/// see, or they are pruned from every locale. Naming a `Menu`
/// REPLACES the choice VoiceOver would read, so each gives the
/// value back explicitly.
extension AppRuleRow {
    /// Space assignment dropdown (`app_rules.space`, drawn under
    /// the "Opens in" heading). No unset item: the absence of a
    /// pin renders as an absence — a dash — and the way back to it
    /// is the CLEAR BUTTON beside the value, never a value named
    /// after the absence (#1022 retired `Automatic`, and a menu
    /// item spelled "Anywhere" is `Automatic` under a new name).
    var spaceMenu: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(model.config.spaces, id: \.raw) { space in
                    Button(space.raw) {
                        model.config.appRules[app] = space
                    }
                }
            } label: {
                menuLabel(spaceCellText)
            }
            .menuStyle(.borderlessButton)
            .neutralMenuLabel()
            // Hugs its content only where NO column constrains it.
            // `.fixedSize()` unconditionally made the Menu ignore
            // its 130 pt frame and draw over the float cell beside
            // it — a Space named "development" was enough, and
            // nothing caps a Space name (code review, 2026-09-22).
            .fixedSize(horizontal: stacked, vertical: false)
            .modifier(
                GreyOut(
                    active: pinVerdict == .unavailable,
                    help: noSpacesHelp
                )
            )
            .accessibilityLabel(L("app_rules.space", "Opens in"))
            .accessibilityValue(spaceFacetLabel)
            clearPinButton
        }
    }

    /// The pin's SPOKEN value, and the canonical one. A dash reads
    /// as nothing aloud, so the drawn cell diverges from this by
    /// necessity rather than by choice — `spaceCellText` is the
    /// variant and the two must stay in step.
    var spaceFacetLabel: String {
        model.config.appRules[app]?.raw
            ?? L("app_rules.space.none", "No Space")
    }

    /// The pin's DRAWN cell. A dash, not a word: a word here would
    /// be a value naming the absence.
    var spaceCellText: String {
        model.config.appRules[app]?.raw
            ?? L("app_rules.space.dash", "—")
    }

    /// Clears the pin — offered only where the rule survives
    /// without one, which is what makes "a rule must say
    /// something" visible without disabling anything. While the
    /// app tiles there is simply no clear button, rather than a
    /// greyed control owing an explanation.
    @ViewBuilder private var clearPinButton: some View {
        if isPinned, pinVerdict == .free {
            Button {
                model.config.appRules[app] = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L(
                    "app_rules.space.clear",
                    "Remove this app's Space"
                )
            )
        }
    }

    /// Whether this app carries a Space pin right now.
    var isPinned: Bool { model.config.appRules[app] != nil }

    /// What may be done with the pin on this row.
    var pinVerdict: AppRulePin.Verdict {
        AppRulePin.verdict(
            // A row whose pattern editor is open floats as far as
            // this question goes, even before its first pattern
            // exists: the user is composing a titled rule, and
            // forcing the pin mid-composition would pin an app
            // they are floating.
            floats: floatFacet != .never
                || titlesEditing.wrappedValue,
            isOverride: overrideBase != nil,
            hasSpaces: !model.config.spaces.isEmpty
        )
    }

    /// The Space menu's one greyed state, whose cause lives on
    /// another destination — so the card draws a live pointer to
    /// it rather than leaving this hover string to carry it alone
    /// (#815; the census declares the gate and
    /// `GateReasonPlacement` derives the channel).
    private var noSpacesHelp: String {
        L(
            "app_rules.space.no_spaces",
            "This profile has no Spaces to open an app in yet."
        )
    }

    /// Float behavior dropdown (`app_rules.float`), drawn with no
    /// column heading: its values are whole predicates and name
    /// themselves. The titled choice is an OFFER (#1022) —
    /// withheld in Simple until some row carries a pattern, and
    /// hidden rather than greyed, per the 2026-08-04 ruling that
    /// mode-withheld surface is absent in this window.
    var floatMenu: some View {
        Menu {
            Button(neverLabel) { setNever() }
                // Grey rather than refuse silently: with no Space
                // to open in, `setNever` returns and the menu
                // still reads "Floats always" with no cue (code
                // review, 2026-09-22).
                .disabled(
                    pinVerdict == .unavailable && !isPinned
                )
            Button(allLabel) { setAll() }
            if offersTitles {
                Button(titledLabel) { openTitles() }
            }
        } label: {
            menuLabel(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize(horizontal: stacked, vertical: false)
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

    /// "always" is shorthand for the app's ORDINARY windows: a
    /// dialog, a sheet and a picture-in-picture window float with
    /// no rule at all, which the user guide carries. It earns the
    /// overclaim by making the trio scan as one set against the
    /// conditional third choice.
    private var neverLabel: String {
        L("app_rules.float.never", "Tiles always")
    }

    private var allLabel: String {
        L("app_rules.float.all_windows", "Floats always")
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "Floats if titled…")
    }

    /// The resting VALUE drops the menu item's ellipsis: an
    /// ellipsis promises further UI — right on a choice opening
    /// the pattern editor, wrong on a value at rest.
    private var restingTitledLabel: String {
        L("app_rules.float.titled.resting", "Floats if titled")
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
    /// one where the row has none — the one consequence that keeps
    /// every row a live rule. Asked of the verdict, so the write
    /// and the clear button cannot disagree about the exceptions.
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

    /// The Space a forced pin takes, nil where there is none. In
    /// override mode that is the BASE's own Space, so a tombstoned
    /// row re-pins to what it removed rather than to the fallback.
    var prospectiveSpace: SpaceID? {
        AppRulePin.engagedSpace(
            model.config,
            inherited: overrideBase?[app]
        )
    }

    /// Opens the pattern editor WITHOUT clearing the float rule.
    ///
    /// The clear used to happen here, and it deleted the row: a
    /// float-only row's bare rule is its only stored rule, so
    /// removing it dropped the app out of `AppRulesSection.apps`
    /// mid-composition. Nothing needs it —
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
    /// opens in work" is a legal rule, the clear button is right
    /// there, and remembering which gesture authored a stored
    /// value is the session state #1022 deleted.
    private func setAll() {
        clearFloatRules()
        model.config.floatRules.append(app)
    }
}
