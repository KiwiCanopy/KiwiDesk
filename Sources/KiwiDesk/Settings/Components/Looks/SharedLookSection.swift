import KiwiDeskCore
import SwiftUI

/// "Shared look" (#1752): the card at the top of Looks & Animations
/// choosing whether this page's profile wears the one shared look or
/// keeps its own (#2820), and naming who else wears it. It gates the
/// Looks, palette and Glass cards below it; Animations stays per
/// profile.
struct SharedLookSection: View {
    @ObservedObject var model: SettingsModel
    @State var shareRequest: LookShareRequest?

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
                "A look is every color, the bars' styling, Liquid "
                    + "Glass, the focus border's shape, the window "
                    + "gaps and the animations."
            )
        ) {
            SettingsRowShape(controlTrails: true) {
                SettingsRowLabel(label: choiceLabel)
            } control: {
                choice
                    .disabled(greyReason != nil || model.isDirty)
            }
            if let greyReason {
                Text(greyReason)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let edited {
                notes(edited)
                if model.isDirty {
                    Text(
                        L(
                            "looks.reach.unsaved",
                            "Save or revert your changes first."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                }
            }
        }
        .sheet(item: $shareRequest) { request in
            LookShareSheet(request: request) { choice, saveFirst in
                answer(request, choice, saveFirst: saveFirst)
            }
        }
    }

    private var choiceLabel: String { L("looks.reach.choice", "Look") }

    /// Why the control greys: a Lua-owned config sets its own look,
    /// and a built-in layout has no file to own one in.
    private var greyReason: String? {
        if !model.guiManaged {
            return L(
                "looks.reach.lua_owned",
                "Your configuration is written in init.lua, which sets "
                    + "the look itself."
            )
        }
        guard edited == nil else { return nil }
        return L(
            "looks.reach.built_in",
            "Save this layout as a profile to choose whether it "
                + "shares the look."
        )
    }

    @ViewBuilder
    private func notes(_ profile: String) -> some View {
        let follows = model.lookFollows[profile] == true
        let users = model.sharedLookUsers(besides: profile)
        VStack(alignment: .leading, spacing: 2) {
            Text(
                follows
                    ? L(
                        "looks.shared.follows",
                        "Changing the look reaches every profile that "
                            + "uses it."
                    )
                    : L(
                        "looks.shared.own",
                        "This profile has its own look — changing it "
                            + "reaches no other profile."
                    )
            )
            .foregroundStyle(SettingsTheme.ink2)
            if follows, !users.isEmpty {
                Text(
                    L(
                        "looks.shared.also_used_by",
                        "Also used by %1$@.",
                        ListFormatter.localizedString(byJoining: users)
                    )
                )
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}
