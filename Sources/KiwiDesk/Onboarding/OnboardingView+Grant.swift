import KiwiDeskCore
import SwiftUI

/// The tour's first screen — the only one carrying the
/// wordmark, and the one that narrates the retile.
extension OnboardingView {

    /// The tour's first screen, and the only one that carries the
    /// wordmark: the wordmark is the app introducing itself, which
    /// happens once. It is a mark-plus-name-plus-tagline lockup,
    /// so the kiwi mark is already inside it and adding a separate
    /// one would put both on a single surface.
    var grant: some View {
        VStack(spacing: 14) {
            wordmark
            Text(
                model.isTrusted
                    ? L(
                        "onboarding.grant.done.title",
                        "Your windows are arranged"
                    )
                    : L(
                        "onboarding.grant.title",
                        "KiwiDesk needs Accessibility"
                    )
            )
            .font(.title.bold())
            .multilineTextAlignment(.center)
            Text(model.isTrusted ? grantedBody : grantBody)
                .multilineTextAlignment(.leading)
                .foregroundStyle(SettingsTheme.ink2)
            Spacer()
            if model.isTrusted {
                Button(L("onboarding.continue", "Continue")) {
                    model.continueAfterAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            } else {
                Button(
                    L(
                        "common.open_system_settings",
                        "Open System Settings"
                    )
                ) {
                    model.onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            waitingLine
            trustLine
        }
    }

    private var wordmark: some View {
        Group {
            if let image = brandWordmark {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    // Sized by WIDTH: a lockup has no point size,
                    // and 180 pt in the 456 pt content column
                    // reads as a logo rather than as a splash.
                    .frame(width: 180)
            } else {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 40))
            }
        }
        .accessibilityLabel(L("brand.menu_bar_icon.a11y", "KiwiDesk"))
    }

    private var brandWordmark: NSImage? {
        colorScheme == .dark
            ? (BrandAssets.wordmarkDark ?? BrandAssets.wordmark)
            : BrandAssets.wordmark
    }

    /// The status glyph, at TEXT height rather than as a 56 pt
    /// hero: the wordmark owns the hero slot on this screen, and
    /// two marks in one slot is one too many. It is never deleted
    /// — lock-versus-check is the only feedback the auto-detect
    /// gives, and it is the channel that separates the two states
    /// now that neither is coloured.
    ///
    /// **Uncoloured is a ruling, not an omission**, and it
    /// survived the tint (#828): accent on the checkmark would put
    /// hue back as the channel telling the two states apart, on
    /// the app's own green, which is the exact defect this tree
    /// shipped as a raw `.green`/`.orange` hero.
    private var waitingLine: some View {
        Label {
            Text(
                model.isTrusted
                    ? L(
                        "onboarding.grant.granted",
                        "Permission granted"
                    )
                    : L(
                        "onboarding.grant.waiting",
                        "Waiting for permission…"
                    )
            )
        } icon: {
            Image(
                systemName: model.isTrusted
                    ? "checkmark.circle.fill"
                    : "lock.shield"
            )
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
        .animation(.default, value: model.isTrusted)
    }

    /// SIP and keylogging are the two objections a macOS user
    /// actually has to an Accessibility prompt, so this is the
    /// line that earns the grant. It survived the welcome step's
    /// deletion as a caption rather than a paragraph.
    private var trustLine: some View {
        Text(
            L(
                "onboarding.grant.trust",
                "KiwiDesk never reads your keystrokes, and never "
                    + "asks you to disable System Integrity "
                    + "Protection."
            )
        )
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(SettingsTheme.ink3)
    }

    /// Step 1 names the button below it, so that name is
    /// INTERPOLATED from the button's own key rather than
    /// re-typed (#818). Quoting a label as literal text makes
    /// every locale hold two strings that must agree forever
    /// with nothing checking that they do; #817 merged the
    /// button's two keys into one and left this third copy of
    /// the words behind.
    private var grantBody: String {
        L(
            "onboarding.grant.body",
            """
            1. Click “%1$@” below.
            2. Find KiwiDesk in the list and turn it on.
            3. Come back here — we detect it automatically.
            """,
            L("common.open_system_settings", "Open System Settings")
        )
    }

    /// The moment the grant lands, `startManaging()` arranges
    /// every window behind this one. That is the demonstration —
    /// on the user's own windows, at the moment it means
    /// something — and until #678 Phase 4 pass 11 the tour said
    /// nothing about it and answered with "Permission granted!".
    ///
    /// The second sentence answers "why is this window special"
    /// outright, once. Said once, the exception stops reading as
    /// an inconsistency and starts reading as a rule.
    private var grantedBody: String {
        L(
            "onboarding.grant.done.body",
            """
            Take a look behind this window — your open windows \
            have been arranged.

            Setup windows like this one are left alone, because \
            they go away.
            """
        )
    }
}
