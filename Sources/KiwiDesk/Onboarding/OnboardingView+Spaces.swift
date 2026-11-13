import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// Tour screen presenting the seeded spaces (#678, #768, #828).
    var spaces: some View {
        let start = model.start
        return OnboardingPage(
            title: spacesTitle,
            body1: spacesBody,
            body2: spacesLayoutsDiffer,
            back: model.back
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OnboardingStartPicker(start: start)
                spaceColumns(start)
            }
        } action: {
            HStack(spacing: 10) {
                if start.hasReplaced {
                    Button(L("onboarding.looks.revert", "Revert")) {
                        start.revert()
                    }
                    .settingsActionButton()
                }
                Button(L("onboarding.continue", "Continue")) {
                    start.commit { model.continueAfterSpaces() }
                }
                .kiwiProminentButton()
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear { start.refresh() }
    }

    /// The picked option's Spaces, one column per screen, each row
    /// playing its layout's story once, staggered (#1750, #3294).
    /// It takes the height the page has free and fades its edge
    /// while rows overflow (#2705).
    private func spaceColumns(_ start: OnboardingStartModel) -> some View {
        ScrollView(.vertical) {
            OnboardingScreenColumns(
                columns: start.selected.map(start.columns) ?? [],
                settings: model.tilingSettings(),
                restsOnAppear: model.spacesPlayed,
                revision: start.revision
            )
            .padding(.bottom, 2)
        }
        .moreBelowFade()
        .frame(maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spacesTitle)
    }

    /// Start offset for row `index`: the first screenful plays
    /// top to bottom, a later row at once on scrolling in.
    static func stagger(_ index: Int) -> Double {
        index < 3 ? Double(index) * 0.4 : 0
    }

    /// Names the screen the setup was chosen for when it is the
    /// starter (#1662), the plain heading otherwise.
    private var spacesTitle: String {
        model.starterTitle()?.onboardingTitle
            ?? L(
                "onboarding.starter_spaces.title",
                "Your Spaces are ready"
            )
    }

    /// Explanatory body describing starter spaces and layout assignments
    /// (#828).
    private var spacesBody: String {
        L(
            "onboarding.starter_spaces.body",
            "Use these the way you used your Mac's Desktops — "
                + "one keystroke away, but each one arranges its "
                + "windows for you. Each has its own layout, "
                + "chosen for your setup."
        )
    }

    /// A layout is a behaviour, not a look, and each Space's can
    /// be changed (#1534); the rows show each one's (#1750).
    /// The breadcrumb's segments are the window's and the pane's
    /// own labels (#818).
    private var spacesLayoutsDiffer: String {
        L(
            "onboarding.starter_spaces.layouts_differ",
            "Each row shows how its layout behaves, and you can "
                + "change a Space's layout later under %1$@ ▸ %2$@.",
            L("home.title", "Settings"),
            SettingsDestination.spaces.title
        )
    }
}
