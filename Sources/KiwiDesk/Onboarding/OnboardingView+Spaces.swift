import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// Tour screen presenting the seeded spaces (#678, #768, #828).
    var spaces: some View {
        OnboardingPage(
            title: spacesTitle,
            body1: spacesBody,
            body2: spacesLayoutsDiffer,
            footnote: spacesFooter,
            footnoteAtBottom: true,
            hint: L(
                "onboarding.starter_spaces.hint",
                "More Spaces or other layouts? Settings, "
                    + "whenever you want them."
            )
        ) {
            spaceStrip
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSpaces()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// Vertical list of space rows, each playing its layout's
    /// story once, staggered down the first screenful (#1750).
    private var spaceStrip: some View {
        ScrollView(.vertical, showsIndicators: false) {
            // Lazy, so a row below the fold plays when it
            // scrolls into view rather than unseen on arrival.
            LazyVStack(spacing: 8) {
                let cards = model.starterSpaces()
                let settings = model.tilingSettings()
                ForEach(Array(cards.enumerated()), id: \.element.id) {
                    index,
                    card in
                    OnboardingSpaceRow(
                        card: card,
                        settings: settings,
                        delay: Self.stagger(index)
                    )
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxHeight: 232)
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

    /// Explains how Spaces relate to native macOS Desktops (#828).
    private var spacesFooter: String {
        L(
            "onboarding.starter_spaces.footer",
            "Rename or change any of these Spaces in Settings, "
                + "whenever you want to. Your Mac's own Desktops "
                + "still exist underneath — one of them can hold "
                + "a whole set of these, though you will not "
                + "need that for a long time."
        )
    }
}
