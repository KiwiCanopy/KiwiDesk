import AppKit
import Foundation
import KiwiDeskCore
import SwiftUI

/// First-run onboarding banner state management
/// (`OnboardingDiscovery.markShown()`).
enum HomeFirstRunState {
    static let seededKey = "home.firstRunSeeded"
    static let retiredKey = "home.firstRunRetired"

    static func shouldShow(
        _ defaults: UserDefaults
    ) -> Bool {
        defaults.bool(forKey: seededKey)
            && !defaults.bool(forKey: retiredKey)
    }

    /// Seeds first-run state on onboarding completion.
    static func seed(_ defaults: UserDefaults) {
        defaults.set(true, forKey: seededKey)
    }

    static func retire(_ defaults: UserDefaults) {
        defaults.set(true, forKey: retiredKey)
    }
}

/// First-run banner displayed on Settings Home view (`GuideLink`, #1019).
struct HomeFirstRunBanner: View {
    @ObservedObject var model: SettingsModel
    @Binding var visible: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(SettingsTheme.accent)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "home.firstrun.title",
                        "You are already set up"
                    )
                )
                .font(.headline)
                .foregroundStyle(SettingsTheme.ink)
                Text(lede)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                GuideLink(ink: SettingsTheme.ink2)
            }
            Spacer()
            Button(
                L("home.firstrun.tour", "Show me around")
            ) {
                model.onShowTour()
            }
            .settingsActionButton()
            .controlSize(.small)
            Button {
                HomeFirstRunState.retire(
                    model.preferences
                )
                visible = false
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L("home.firstrun.dismiss", "Dismiss")
            )
        }
        .padding(12)
        // Card chrome, never the paused bar's amber (failure
        // outranks welcome). A plain HAIRLINE, not an accent
        // border: a hovered Home card is card-fill + accent
        // border, and this banner sits directly above the grid —
        // an accent here put two pixel-identical boxes meaning
        // "hovering" and "welcome".
        .background(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .strokeBorder(SettingsTheme.hairline)
            )
        )
    }

    private var lede: String {
        if let profile = model.activeProfile {
            return L(
                "home.firstrun.lede_profile",
                "%1$d Spaces, keys bound, saved as %2$@. "
                    + "Nothing below needs your attention — "
                    + "this is where you come when you want "
                    + "something different.",
                model.config.spaces.count,
                profile
            )
        }
        return L(
            "home.firstrun.lede",
            "%1$d Spaces are set up and your keys are "
                + "bound. Nothing below needs your attention "
                + "— this is where you come when you want "
                + "something different.",
            model.config.spaces.count
        )
    }
}
