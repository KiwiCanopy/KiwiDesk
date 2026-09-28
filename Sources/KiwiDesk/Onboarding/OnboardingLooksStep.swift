import AppKit
import KiwiDeskCore
import SwiftUI

/// The tour's looks step (#1720): the bundled looks over the
/// palettes, each click painted live onto the real shelf. Marks
/// are computed from the live settings, never stored (#757).
struct OnboardingLooksStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var live: TilingSettings {
        _ = model.looksRevision
        return model.tilingSettings()
    }

    private var blocked: Bool {
        _ = model.looksRevision
        return model.settingsDraftPending()
    }

    var body: some View {
        OnboardingPage(
            title: L(
                "onboarding.looks.title",
                "Choose how KiwiDesk looks"
            ),
            body1: L(
                "onboarding.looks.body",
                "Pick a look and KiwiDesk changes as you click: "
                    + "the bars that show your Spaces and windows, "
                    + "and the border around the focused window. "
                    + "Then pick the colors."
            ),
            footnote: blocked ? blockedCaption : nil,
            hint: laterHint
        ) {
            rows(live)
                .disabled(blocked)
        } action: {
            actions
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification
            )
        ) { _ in
            model.refreshLooks()
        }
    }

    private func rows(_ live: TilingSettings) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingLookRow(
                looks: model.shelfLooks(),
                live: live,
                spaceLabels: model.spaceLabels(),
                palette: model.palette(of:),
                pick: pick
            )
            OnboardingPaletteRow(
                palettes: model.shelfPalettes(),
                live: live,
                reduceMotion: reduceMotion,
                pick: model.pickPalette
            )
        }
    }

    private func pick(_ look: ShelfLook) {
        model.pickLook(look)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(L("onboarding.looks.revert", "Revert")) {
                model.revertLooks()
            }
            .settingsActionButton()
            .disabled(!model.hasLookChanges || blocked)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterLooks()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// The Save pill's own labels, so the sentence names the
    /// buttons the user will find (#818).
    private var blockedCaption: String {
        L(
            "onboarding.looks.draft_pending",
            "Settings has changes you haven't saved. Choose %1$@ "
                + "or %2$@ there to pick a look here.",
            L("footer.save", "Save"),
            L("footer.revert", "Revert")
        )
    }

    private var laterHint: String {
        L(
            "onboarding.looks.hint",
            "Change either later under %1$@ ▸ %2$@.",
            L("home.title", "Settings"),
            SettingsDestination.looks.title
        )
    }
}
