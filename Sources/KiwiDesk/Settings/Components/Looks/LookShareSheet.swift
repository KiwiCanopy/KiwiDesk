import KiwiDeskCore
import SwiftUI

/// What switching an own-look profile to Shared shows (#2820): the
/// two looks side by side, built by the host from the draft.
struct LookShareRequest: Identifiable {
    var id: String { profile }
    let profile: String
    /// The draft as it is, and the draft wearing the shared look.
    let own: TilingSettings
    let shared: TilingSettings
    let spaceLabels: [SpaceGlyph]
    /// The other profiles wearing the shared look.
    let users: [String]
    /// The library look the own look already is, if any.
    let savedAs: String?
}

/// The answer the sheet hands back through its host's closure.
enum LookShareChoice {
    case useShared
    case makeShared
}

/// The prompt switching an own-look profile to Shared (#2820 ▸
/// Ruling 3): use the shared look or make this one the shared look,
/// naming the profiles that change, and an offer to keep the own
/// look in My looks first. It writes nothing itself: the host's
/// closures stage the answer.
struct LookShareSheet: View {
    let request: LookShareRequest
    let answer: (LookShareChoice, _ saveFirst: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saveFirst = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(context)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            pictures
            saveOffer
            buttons
        }
        .padding(20)
        .frame(width: 480)
    }

    private var question: String {
        L(
            "looks.reach.prompt.question",
            "Use the Shared Look on “%1$@”?",
            request.profile
        )
    }

    private var context: String {
        guard !request.users.isEmpty else {
            return L(
                "looks.reach.prompt.context_alone",
                "“%1$@” has its own look. No other profile uses "
                    + "the shared look.",
                request.profile
            )
        }
        return L(
            "looks.reach.prompt.context",
            "“%1$@” has its own look. These profiles use the "
                + "shared look: %2$@",
            request.profile,
            LocalizedList.join(request.users)
        )
    }

    private var pictures: some View {
        HStack(alignment: .top, spacing: 12) {
            picture(
                request.own,
                caption: L(
                    "looks.reach.prompt.own_picture",
                    "This profile's look"
                )
            )
            picture(
                request.shared,
                caption: L(
                    "looks.reach.prompt.shared_picture",
                    "Shared look"
                )
            )
        }
        .accessibilityHidden(true)
    }

    private func picture(
        _ settings: TilingSettings,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LookPlate(settings: settings, spaceLabels: request.spaceLabels)
            Text(caption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
        }
    }

    @ViewBuilder private var saveOffer: some View {
        if let savedAs = request.savedAs {
            Text(
                L(
                    "looks.reach.prompt.already_saved",
                    "Already in %1$@ as “%2$@”.",
                    myLooks,
                    savedAs
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
        } else {
            Toggle(
                L(
                    "looks.reach.prompt.save_first",
                    "Save the current look of “%1$@” to %2$@ first",
                    request.profile,
                    myLooks
                ),
                isOn: $saveFirst
            )
            .toggleStyle(.checkbox)
        }
    }

    private var buttons: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // A long translation stacks the three rather than cut a
            // title (localization.md ▸ #859).
            ViewThatFits(in: .horizontal) {
                HStack {
                    Spacer()
                    actions
                }
                VStack(alignment: .trailing, spacing: 6) { actions }
            }
            if !request.users.isEmpty {
                Text(
                    L(
                        "looks.reach.prompt.make_reaches",
                        "“%1$@” also changes %2$@.",
                        makeTitle,
                        LocalizedList.join(request.users)
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    @ViewBuilder private var actions: some View {
        Button(L("looks.reach.prompt.cancel", "Cancel")) { dismiss() }
            .keyboardShortcut(.cancelAction)
            .settingsActionButton()
        Button(makeTitle) { choose(.makeShared) }
            .settingsActionButton()
        Button(L("looks.reach.prompt.use", "Use the Shared Look")) {
            choose(.useShared)
        }
        .keyboardShortcut(.defaultAction)
        .kiwiProminentButton()
    }

    private var makeTitle: String {
        L("looks.reach.prompt.make", "Make This the Shared Look")
    }

    /// The library section's own title, interpolated (gui.md).
    private var myLooks: String { L("looks.mine", "My looks") }

    private func choose(_ choice: LookShareChoice) {
        answer(choice, request.savedAs == nil && saveFirst)
        dismiss()
    }
}
