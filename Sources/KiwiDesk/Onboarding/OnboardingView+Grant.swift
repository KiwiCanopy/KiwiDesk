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
    ///
    /// The numbered instructions sit in a card, as the prototype
    /// draws them (#828): they are a procedure the user carries
    /// out in another app, so they read as a list of things to do
    /// rather than as a paragraph about the permission.
    var grant: some View {
        OnboardingPage(
            title: grantTitle,
            body1: grantBody,
            hint: model.isTrusted ? nil : grantHint
        ) {
            wordmark
            if model.isTrusted {
                grantedMark
                if case .scanning(let scanned, let total) =
                    model.bootPhase
                {
                    arrangingLine(scanned: scanned, total: total)
                }
            } else {
                grantSteps
            }
        } action: {
            if model.isTrusted {
                Button(L("onboarding.continue", "Continue")) {
                    model.continueAfterAccessibility()
                }
                .kiwiProminentButton()
                .keyboardShortcut(.defaultAction)
            } else {
                Button(
                    L(
                        "common.open_system_settings",
                        "Open System Settings"
                    )
                ) {
                    model.onOpenSettings()
                }
                .kiwiProminentButton()
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    /// Three states, not two: waiting for the grant, arranging,
    /// arranged. The middle one exists because the boot is chunked
    /// now (#801) — the Continue button answers immediately, so
    /// this screen is read while the scan is still running, and
    /// the finished-job copy would be the only thing lying about
    /// it.
    /// Internal, not private: the three states are a surfacing
    /// branch, and `OnboardingGrantPhaseTests` reads them — a
    /// branch inside a `body` is exactly what every other guard
    /// passes over (gui.md).
    var grantTitle: String {
        guard model.isTrusted else {
            return L(
                "onboarding.grant.title",
                "KiwiDesk needs Accessibility"
            )
        }
        return model.bootPhase.isStarting
            ? L(
                "onboarding.grant.arranging.title",
                "Arranging your windows"
            )
            : L(
                "onboarding.grant.done.title",
                "Your windows are arranged"
            )
    }

    var grantBody: String {
        guard model.isTrusted else { return grantLead }
        return model.bootPhase.isStarting
            ? L(
                "onboarding.grant.arranging.body",
                """
                Permission is on. KiwiDesk is going through your \
                open windows now — on a busy Mac this takes a \
                moment.

                Setup windows like this one are left alone, \
                because they go away.
                """
            )
            : grantedBody
    }

    /// The same determinate count the quick menu shows, in the
    /// same words: one fact, and a user who checks both must not
    /// find two numbers. The dot is the tour's existing waiting
    /// vocabulary, so the state reads as continuing rather than as
    /// a new kind of progress.
    private func arrangingLine(
        scanned: Int,
        total: Int
    ) -> some View {
        HStack(spacing: 9) {
            WaitingDot()
            Text(
                L(
                    "onboarding.grant.arranging.count",
                    "Apps scanned: %1$d of %2$d",
                    scanned,
                    total
                )
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(SettingsTheme.ink3)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    private var wordmark: some View {
        Group {
            if let image = brandWordmark {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    // Sized by WIDTH: a lockup has no point size,
                    // and 180 pt in the content column reads as a
                    // logo rather than as a splash.
                    .frame(width: 180)
            } else {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 40))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel(L("brand.menu_bar_icon.a11y", "KiwiDesk"))
    }

    private var brandWordmark: NSImage? {
        colorScheme == .dark
            ? (BrandAssets.wordmarkDark ?? BrandAssets.wordmark)
            : BrandAssets.wordmark
    }

    /// The two things to do, numbered, plus the line saying the
    /// page continues by itself.
    private var grantSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            grantStep(
                1,
                L(
                    "onboarding.grant.step.open",
                    "Open Privacy & Security ▸ Accessibility"
                )
            )
            grantStep(
                2,
                L(
                    "onboarding.grant.step.enable",
                    "Switch KiwiDesk on"
                )
            )
            waitingLine
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .onboardingCard()
    }

    /// The granted state is the tour's one moment of good news,
    /// so it is drawn as one — centred, at hero size, standing off
    /// the copy above it (owner, 2026-08-12). Before this it was
    /// the same 12.5 pt status line that had been saying
    /// "waiting", which made the app's first success read like a
    /// log entry.
    ///
    /// **The check takes the accent, and that does not reopen the
    /// hue ruling.** What `waitingLine` forbids is hue as the ONLY
    /// channel telling two states apart — which is what a green
    /// check beside an orange lock, at the same size in the same
    /// slot, would be. These two share nothing: the lock is a
    /// 12.5 pt line inside the instruction card, this is a 34 pt
    /// mark in the middle of the screen with its own sentence
    /// under it. Shape, size, position and words all differ before
    /// colour is asked to say anything.
    private var grantedMark: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(SettingsTheme.accent)
            Text(
                L("onboarding.grant.granted", "Permission granted")
            )
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(SettingsTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }

    private func grantStep(
        _ number: Int,
        _ text: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.groupHeading)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(SettingsTheme.sunken)
                )
            Text(text)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        // One element: the number and the instruction are one
        // step, and read apart the number is an unnamed digit.
        .accessibilityElement(children: .combine)
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
        HStack(spacing: 9) {
            WaitingDot()
            Text(
                L(
                    "onboarding.grant.waiting",
                    "Waiting — this page continues by itself"
                )
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(SettingsTheme.ink3)
        // The dot is decoration; the sentence carries the state,
        // so VoiceOver reads one thing rather than an unnamed
        // shape followed by a line of text.
        .accessibilityElement(children: .combine)
    }

    /// SIP and keylogging are the two objections a macOS user
    /// actually has to an Accessibility prompt, so this is the
    /// line that earns the grant. It sits in the footer, opposite
    /// the button it earns.
    private var grantHint: String {
        L(
            "onboarding.grant.trust",
            "KiwiDesk never reads your keystrokes, and never "
                + "asks you to disable System Integrity "
                + "Protection."
        )
    }

    /// What the permission is FOR, in one sentence.
    ///
    /// The numbered procedure moved into `grantSteps`, so this no
    /// longer interpolates the button's label — the list below it
    /// is the instruction now, and step 1 named a button the user
    /// can see (#818's obligation is on a sentence NAMING a
    /// control; this one names none).
    private var grantLead: String {
        L(
            "onboarding.grant.lead",
            "macOS only lets an app move windows once you allow "
                + "it. Nothing here works until this is on."
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
