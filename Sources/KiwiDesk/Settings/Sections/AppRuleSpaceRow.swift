import KiwiDeskCore
import SwiftUI

/// One row of the "Open in a Space" list: an app and the Space
/// its new windows open in (#1608).
///
/// The Space applies to EVERY window of the app, whatever its
/// title — which is why it is a list of its own rather than a
/// column beside the float facet, where a title pattern below the
/// row read as scoping the Space too (owner, on device,
/// 2026-09-23).
struct AppRuleSpaceRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Base pins while a stored profile is edited (#109); nil
    /// during live editing.
    let overrideBase: [String: SpaceID]?
    /// The area's census gates, built by the section alone.
    let gates: AppRulesGates
    let onDelete: () -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AppRuleIdentity(app: app)
            spaceMenu
                .opacity(inherited ? 0.55 : 1)
                // The row's focus destination (#816).
                .focused($returningRow, equals: app)
            Spacer(minLength: 8)
            AppRuleDeleteButton(help: removeHelp, onDelete: onDelete)
                .disabled(tombstoned)
        }
        .font(.callout)
    }

    /// No "none" item: a row in this list HAS a Space, and the way
    /// to stop opening an app in one is the trash. The one
    /// exception is an override tombstone, drawn as a dash below.
    private var spaceMenu: some View {
        Menu {
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) {
                    model.config.appRules[app] = space
                }
            }
        } label: {
            AppRuleMenuLabel(text: cellText)
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

    /// The SPOKEN value. A dash reads as nothing aloud, so only the
    /// tombstone differs from the drawn cell.
    var spaceFacetLabel: String {
        spaceText(ifNone: L("app_rules.space.none", "No Space"))
    }

    private var cellText: String {
        spaceText(ifNone: L("app_rules.dash", "—"))
    }

    private func spaceText(ifNone none: String) -> String {
        model.config.appRules[app]?.raw ?? none
    }

    /// A profile's stored nil un-pins an app the base pins, so the
    /// row stays listed with nothing left for the trash to remove;
    /// picking a Space restores a pin.
    private var tombstoned: Bool {
        overrideBase != nil && model.config.appRules[app] == nil
    }

    /// In sync with the base, which the 0.55 dim says.
    private var inherited: Bool {
        guard let base = overrideBase?[app] else { return false }
        return model.config.appRules[app] == base
    }

    private var removeHelp: String {
        overrideBase == nil
            ? L(
                "app_rules.space.remove.help",
                "Stop opening this app in a Space"
            )
            : L(
                "app_rules.space.remove_override.help",
                "Stop opening this app in a Space in this profile"
            )
    }

    private var noSpacesHelp: String {
        L(
            "app_rules.space.no_spaces",
            "This profile has no Spaces to open an app in yet."
        )
    }
}
