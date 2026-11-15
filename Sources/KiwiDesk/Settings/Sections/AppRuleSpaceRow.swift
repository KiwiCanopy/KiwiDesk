import KiwiDeskCore
import SwiftUI

/// One row of the "Open in a Space" list (#1608, #3341): an app,
/// which of its windows the row takes — all of them, the others, or
/// those titled with a fragment — the Space they open in, and which
/// profiles the rule reaches (#1393). The app's name shows on its
/// group's first row only.
struct AppRuleSpaceRow: View {
    @ObservedObject var model: SettingsModel
    let row: SpaceRuleRow
    /// Whether the row draws its app's name.
    let first: Bool
    /// The app's titled rows, which make a bare row "All other
    /// windows" and which a composed fragment may not repeat.
    let siblings: [String]
    /// The area's census gates, built by the section alone.
    let gates: AppRulesGates
    /// Whether the section draws the "Applies to" column.
    let showsReach: Bool
    /// The section's one open composer.
    @Binding var composing: SpaceComposer?
    let onDelete: (RuleRemoval) -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?
    /// The pattern being composed in the scope cell.
    @State var draft = TitlePatternDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: SettingsMetrics.appRuleColumnSpacing
            ) {
                identity
                scopeCell
                if !isDraft { controls }
            }
            .font(.callout)
            if composingHere {
                VStack(alignment: .leading, spacing: 3) {
                    SpaceRuleMatchPreview(
                        model: model,
                        row: row,
                        space: composedSpace,
                        pending: draft.isOpen ? draft.text : ""
                    )
                    Text(AppRuleScopeWords.caption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, SettingsMetrics.appRuleIdentityInset)
            }
        }
        // A row past its group's first names its app for VoiceOver,
        // the name being drawn on the first row alone.
        .modifier(SpaceRowGroupName(name: first ? nil : appName))
    }

    /// The group's first row draws the app; the rest keep its width.
    @ViewBuilder private var identity: some View {
        if first {
            AppRuleIdentity(app: row.app)
        } else {
            AppRuleIdentity(app: row.app).hidden()
        }
    }

    @ViewBuilder private var controls: some View {
        spaceMenu
            .focused($returningRow, equals: focusValue(menu: true))
        if showsReach, let reading {
            RuleReachControl(
                model: model,
                family: family,
                app: row.key,
                subject: subject,
                reading: reading,
                value: spaceFacetLabel
            )
        }
        Spacer(minLength: SettingsMetrics.appRuleColumnSpacing)
        AppRuleDeleteButton(
            help: removeHelp,
            sharedFrom: sharedFrom,
            onDelete: onDelete
        )
        .focused($returningRow, equals: focusValue(menu: false))
    }

    var appName: String {
        KeybindingCatalog.displayName(forBundleID: row.app)
    }

    /// The row in words, for the reach checklist.
    private var subject: String {
        guard let fragment = row.fragment else { return appName }
        return SettingsValueReadout.instanceLabel(
            appName,
            AppRuleScopeWords.titled(fragment)
        )
    }

    var family: RuleFamily { row.fragment == nil ? .space : .titledSpace }

    private var reading: RuleReachReading? {
        row.fragment == nil
            ? model.spaceReach(row.app) : model.titledSpaceReach(row.key)
    }

    /// The edited profile, where the trash must ask: another
    /// profile uses this rule too.
    private var sharedFrom: RuleReachReading? {
        guard showsReach, let reading, reading.users.count > 1
        else { return nil }
        return reading
    }

    /// The row's focus destination (#816) must be able to HOLD
    /// focus: the Space menu, except while no Space is declared and
    /// the menu is greyed, when it is the trash. The other control
    /// takes a per-row value no deletion ever assigns.
    private func focusValue(menu: Bool) -> String {
        menu == gates.hasSpaces ? row.key : row.key + "\u{0}"
    }

    /// No "none" item: a row in this list HAS a Space, and the way
    /// to stop opening an app in one is the trash.
    private var spaceMenu: some View {
        Menu {
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) { pick(space) }
            }
            temporarySpaces
        } label: {
            AppRuleMenuLabel(text: spaceFacetLabel, chevron: false)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .menuTriggerHover()
        .modifier(
            GreyOut(active: !gates.hasSpaces, help: noSpacesHelp)
        )
        .accessibilityLabel(L("app_rules.space", "Opens in"))
        .accessibilityValue(spaceFacetLabel)
    }

    /// The row's one write of its own: the Space it opens in.
    private func pick(_ space: SpaceID) {
        if row.fragment == nil {
            model.config.appRules[row.app] = space
        } else {
            model.config.titledAppRules[row.key] = space
        }
    }

    /// Temporary Spaces cannot be a rule's target (#1790): one row
    /// each, in the Space rows' own shape, leading to the row that
    /// adds it to the profile — greyed, with the reason once, where
    /// no profile file is live. The live page only — a stored
    /// profile's page is another arrangement.
    @ViewBuilder private var temporarySpaces: some View {
        let temporary = model.liveOnlySpaces.filter(\.isTemporary)
        if !model.editingStoredProfile, !temporary.isEmpty {
            let canAdd = temporary.contains(where: \.canAdd)
            Section(
                L(
                    "app_rules.space.temporary_header",
                    "Temporary — not in this profile"
                )
            ) {
                ForEach(temporary) { space in
                    Button(Self.addTemporaryTitle(space.id)) {
                        model.nav.pendingReveal = SettingsAnchor(
                            destination: .spaces,
                            anchor: LiveOnlySpaceRow.anchor(space.id)
                        )
                    }
                    .disabled(!canAdd)
                    .accessibilityLabel(Self.addTemporarySpoken(space.id))
                }
                if !canAdd {
                    Button(Self.noProfile) {}.disabled(true)
                }
            }
        }
    }

    static func addTemporaryTitle(_ space: SpaceID) -> String {
        L(
            "app_rules.space.add_temporary",
            "%1$@ — add it first…",
            space.raw
        )
    }

    static func addTemporarySpoken(_ space: SpaceID) -> String {
        L(
            "app_rules.space.add_temporary.spoken",
            "Space %1$@ is temporary. Add it to this profile to apply "
                + "app rules to it.",
            space.raw
        )
    }

    private static var noProfile: String {
        L(
            "spaces.add_to_profile.no_profile",
            "Save this setup as a profile first"
        )
    }

    /// The drawn and spoken value, one expression.
    var spaceFacetLabel: String {
        SpaceRuleRows.space(of: row, in: model.config)?.raw ?? ""
    }

    private var removeHelp: String {
        L(
            "app_rules.space.remove.help",
            "Stop opening this app in a Space"
        )
    }

    private var noSpacesHelp: String {
        L(
            "app_rules.space.no_spaces",
            "This profile has no Spaces to open an app in yet."
        )
    }
}
