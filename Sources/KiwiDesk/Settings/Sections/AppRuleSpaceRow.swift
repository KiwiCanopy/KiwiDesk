import KiwiDeskCore
import SwiftUI

/// One row of the "Open in a Space" list: an app, the Space its
/// new windows open in, whatever their title (#1608), and which
/// profiles the rule reaches (#1393).
struct AppRuleSpaceRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// The area's census gates, built by the section alone.
    let gates: AppRulesGates
    /// Whether the section draws the "Applies to" column.
    let showsReach: Bool
    let onDelete: (RuleRemoval) -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: SettingsMetrics.appRuleColumnSpacing
        ) {
            AppRuleIdentity(app: app)
            spaceMenu
                .focused($returningRow, equals: focusValue(menu: true))
            if showsReach, let reading {
                RuleReachControl(
                    model: model,
                    family: .space,
                    app: app,
                    subject: KeybindingCatalog.displayName(forBundleID: app),
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
        .font(.callout)
    }

    private var reading: RuleReachReading? { model.spaceReach(app) }

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
        menu == gates.hasSpaces ? app : app + "\u{0}"
    }

    /// No "none" item: a row in this list HAS a Space, and the way
    /// to stop opening an app in one is the trash.
    private var spaceMenu: some View {
        Menu {
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) {
                    model.config.appRules[app] = space
                }
            }
            temporarySpaces
        } label: {
            AppRuleMenuLabel(text: spaceFacetLabel)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .modifier(
            GreyOut(active: !gates.hasSpaces, help: noSpacesHelp)
        )
        .accessibilityLabel(L("app_rules.space", "Opens in"))
        .accessibilityValue(spaceFacetLabel)
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
        model.config.appRules[app]?.raw ?? ""
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
