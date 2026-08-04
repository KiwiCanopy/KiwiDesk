import Foundation
import KiwiDeskCore
import SwiftUI

/// Turn 14c's "You are already set up" beat: Home opens full,
/// not empty, and the banner says so once — the tour seeded a
/// real setup, so the first Settings visit needs orientation,
/// not a wizard. Shows only on Home, only after the tour has
/// run, and retires permanently on dismiss or on the first
/// save/revert (`SettingsModel` applies a dirty draft — the
/// user is past needing it).
enum HomeFirstRunState {
    static let seededKey = "home.firstRunSeeded"
    static let retiredKey = "home.firstRunRetired"

    static func shouldShow(
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: seededKey)
            && !defaults.bool(forKey: retiredKey)
    }

    /// The tour's close marks Home's banner pending — same
    /// moment `OnboardingDiscovery.markShown()` fires.
    static func seed(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seededKey)
    }

    static func retire(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: retiredKey)
    }
}

/// The banner itself: informational card chrome (never the
/// paused bar's amber — failure outranks welcome and must not
/// share its surface), a lead line, the replay button and a
/// permanent dismiss.
struct HomeFirstRunBanner: View {
    @ObservedObject var model: SettingsModel
    /// Re-renders Home after retire — UserDefaults alone would
    /// not invalidate the view.
    @Binding var visible: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(Color.accentColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "home.firstrun.title",
                        "You are already set up"
                    )
                )
                .font(.headline)
                Text(lede)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(
                L("home.firstrun.tour", "Show me around")
            ) {
                model.onShowTour()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button {
                HomeFirstRunState.retire(
                    model.firstRunDefaults
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            Color.accentColor.opacity(0.4)
                        )
                )
        )
    }

    private var lede: String {
        if let profile = model.activeProfile {
            return L(
                "home.firstrun.lede_profile",
                "%1$d spaces, keys bound, saved as %2$@. "
                    + "Nothing below needs your attention — "
                    + "this is where you come when you want "
                    + "something different.",
                model.config.spaces.count,
                profile
            )
        }
        return L(
            "home.firstrun.lede",
            "%1$d spaces are set up and your keys are "
                + "bound. Nothing below needs your attention "
                + "— this is where you come when you want "
                + "something different.",
            model.config.spaces.count
        )
    }
}
