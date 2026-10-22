import AppKit
import KiwiDeskCore
import SwiftUI

/// The tour's bars step (#2515): when the bars show, picked live
/// onto the real bars — the windows making room behind the tour
/// are the preview — with the show/hide keys a hidden bar needs.
struct OnboardingBarsStep: View {
    @Bindable var model: OnboardingModel

    private var bars: OnboardingBarsModel { model.bars }

    var body: some View {
        OnboardingPage(
            title: L(
                "onboarding.bars.title",
                "Choose when the bars show"
            ),
            body1: L(
                "onboarding.bars.body",
                "Keep the Space Bar and App Bar on screen, or hide "
                    + "them and give your windows the whole screen."
            ),
            footnote: bars.blocked ? blockedCaption : nil,
            hint: laterHint
        ) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingBarsTiles(
                    selected: bars.selected,
                    pick: bars.pick
                )
                .disabled(bars.blocked)
                revealKeys
            }
        } action: {
            actions
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.didBecomeKeyNotification
            )
        ) { _ in
            bars.refresh()
        }
    }

    /// Each bar's show/hide chord, under every option: a hidden
    /// bar is reached by it, an auto one by it or the pointer.
    @ViewBuilder private var revealKeys: some View {
        let rows = bars.revealKeys()
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { family in
                    HStack(alignment: .center, spacing: 12) {
                        Text(family.label)
                            .font(.system(size: 13.5))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 12)
                        OnboardingKeycap(family: family)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(L("onboarding.looks.revert", "Revert")) {
                bars.revert()
            }
            .settingsActionButton()
            .disabled(!bars.hasChanges || bars.blocked)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterBars()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// The Save pill's own labels, so the sentence names the
    /// buttons the user will find (#818).
    private var blockedCaption: String {
        L(
            "onboarding.bars.draft_pending",
            "Settings has changes you haven't saved. Choose %1$@ "
                + "or %2$@ there to choose when the bars show here.",
            L("footer.save", "Save"),
            L("footer.revert", "Revert")
        )
    }

    private var laterHint: String {
        L(
            "onboarding.bars.hint",
            "Set each bar on its own later under %1$@ ▸ %2$@.",
            L("home.title", "Settings"),
            SettingsDestination.bars.title
        )
    }
}
