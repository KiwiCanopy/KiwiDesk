import KiwiDeskCore
import SwiftUI

/// "Shared look" (#1752): the card at the top of Looks & Animations
/// saying which profiles wear the one shared look, through the App
/// Rules "Applies to" control with the look's own tick rules
/// (`LookReachChecklist`). It gates the Looks, palette and Glass
/// cards below it; Animations stays per profile.
struct SharedLookSection: View {
    @ObservedObject var model: SettingsModel

    /// The profile whose page this is: the stored one being edited,
    /// else the loaded one; nil while a built-in layout is live.
    var edited: String? {
        model.editingProfile ?? model.activeProfile
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.sharedLook,
            caption: L(
                "looks.shared.caption",
                "A look is the bars' colors and styling, Liquid Glass, "
                    + "the focus border's shape and the window gaps. "
                    + "Animations stay with each profile."
            )
        ) {
            SettingsRowShape {
                SettingsRowLabel(label: appliesTo)
            } control: {
                LookReachControl(model: model, edited: edited ?? "")
                    .disabled(greyReason != nil)
            }
            if let greyReason {
                Text(greyReason)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let edited {
                Text(note(edited))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appliesTo: String { L("app_rules.reach", "Applies to") }

    /// Why the control greys: a Lua-owned config sets its own look,
    /// and a built-in layout has no file to own one in.
    private var greyReason: String? {
        if !model.core.isGuiManaged {
            return L(
                "general.app_wide.lua_owned",
                "Your configuration is written in init.lua, so set "
                    + "this there."
            )
        }
        guard edited == nil else { return nil }
        return L(
            "looks.reach.built_in",
            "Save this layout as a profile to choose whether it "
                + "shares the look."
        )
    }

    private func note(_ profile: String) -> String {
        model.lookFollows[profile] == false
            ? L(
                "looks.shared.own",
                "This profile has its own look — changing it reaches "
                    + "no other profile."
            )
            : L(
                "looks.shared.follows",
                "Changing the look reaches every profile that uses it."
            )
    }
}
