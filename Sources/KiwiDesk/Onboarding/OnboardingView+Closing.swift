import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The multi-display Spaces recommendation (#8), unchanged in
    /// substance and moved to the end of the substantive steps
    /// (#678 Phase 4 pass 11) — it is a recommendation the user
    /// may skip, and it appears only when it can actually bite.
    var separateSpaces: some View {
        OnboardingPage(
            title: L(
                "onboarding.spaces.title",
                "Use shared Desktops across displays"
            ),
            body1: separateSpacesBody,
            hint: L(
                "onboarding.spaces.hint",
                "Skipping is fine — basic tiling works either way."
            )
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 26))
                    .foregroundStyle(SettingsTheme.accent)
                Text(separateSpacesDetail)
                    .font(.system(size: 13.5))
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onboardingCard()
            // Secondary rank through the seal, never a raw
            // `.bordered`: the tinted window paints a bordered
            // button's LABEL from the accent, which is #759 (#828
            // brought the tint here, so it brings the seal too).
            Button(
                L(
                    "onboarding.spaces.open_settings",
                    "Open Desktop & Dock Settings"
                )
            ) {
                model.onOpenSpaceSettings()
            }
            .settingsActionButton()
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSeparateSpaces()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// The consequence, split off the lead so the page's two
    /// tiers carry one idea each: the lead says what to change,
    /// this says what it costs and what happens if you do not.
    private var separateSpacesDetail: String {
        L(
            "onboarding.spaces.detail",
            "Basic tiling still works if you keep it on. "
                + "Changing this setting requires logging out and "
                + "back in."
        )
    }

    private var separateSpacesBody: String {
        L(
            "onboarding.spaces.body",
            "KiwiDesk uses one active profile across all "
                + "displays. For predictable Desktop-to-profile "
                + "bindings, turn off “Displays have separate "
                + "Spaces.”"
        )
    }

    /// The closing card.
    ///
    /// **"Start using it" takes the default action**, and Open
    /// Settings is secondary (#678 Phase 4 pass 11). Return used
    /// to land on Open Settings, which said the opposite of this
    /// app's own ruling that Settings is for people who want to
    /// dig deeper rather than a prerequisite for using the thing.
    var done: some View {
        OnboardingPage(
            title: L(
                "onboarding.ready.title",
                "You're ready to go"
            ),
            body1: doneBody,
            // The link rides INSIDE the sentence, at its own
            // specifier, so a translation places it (#828, owner
            // ruled it a link rather than a button above the
            // fold).
            // The RAW frame, slot intact: `LinkedCaption` draws
            // the label AT `%1$@` and formatting it in first
            // would leave the sentence with no slot to draw at —
            // which is how the first cut shipped the words with
            // no link under them.
            hint: L(
                "onboarding.ready.hint",
                "Tiled before? %1$@"
            ),
            hintLink: .init(
                label: L(
                    "onboarding.ready.open_settings",
                    "Open Settings"
                ),
                action: {
                    model.commitLoginItemThen {
                        model.onExploreSettings()
                    }
                }
            )
        ) {
            menuBarIdentity
            Toggle(
                L(
                    "onboarding.ready.open_at_login",
                    "Open KiwiDesk when I log in"
                ),
                isOn: $model.openAtLogin
            )
            .toggleStyle(.checkbox)
            .onboardingCard()
            // Under the login card, at body size rather than as
            // the page's quiet footnote (owner, 2026-08-12): it
            // is the last thing the tour says, and the prototype
            // gives it the same weight as the copy above.
            Text(onboardingEmphasis(doneClosingNote))
                .font(.system(size: 13))
                .foregroundStyle(SettingsTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        } action: {
            Button(L("onboarding.ready.start", "Start using it")) {
                model.commitLoginItemThen { model.onFinish() }
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// The reassurance, at the quiet tier where it belongs: it is
    /// the honest version of this app — Settings is for people
    /// who want to dig deeper, not a prerequisite for using the
    /// thing.
    private var doneClosingNote: String {
        L(
            "onboarding.ready.footnote",
            // The clause the prototype sets in the strong ink:
            // the sentence is quiet, the permission to ignore
            // Settings is the part that has to land.
            "Settings is where you change any of this — different "
                + "keys, more spaces, other colours. **If this is "
                + "your first tiling manager, you do not need it "
                + "today.**"
        )
    }

    /// Where the app lives, shown INSIDE the window (#828, owner
    /// ruled 2026-08-12).
    ///
    /// It replaces the desktop coach mark that used to float under
    /// the real menu-bar item after the tour closed: an overlay
    /// outside every KiwiDesk window is a surface the app cannot
    /// promise anything about — it pointed at a strip that a
    /// menu-bar manager may have moved, and it skipped itself
    /// entirely under an auto-hidden menu bar, which is precisely
    /// the user who most needs telling. Drawn here, the picture is
    /// on a surface the app owns and every user sees it.
    ///
    /// The mark is the REAL menu-bar image, template-flagged, so
    /// what the user matches against the menu bar is the same
    /// artwork rather than an SF Symbol standing in for it.
    private var menuBarIdentity: some View {
        VStack(spacing: 0) {
            menuBarStrip
            Text(menuBarBody)
                .font(.system(size: 13.5))
                .foregroundStyle(SettingsTheme.ink2)
                // The sentence WRAPS. It shipped clipped at one
                // line in the fixed 520 pt window (owner, on
                // device, 2026-08-12) — a picture with half a
                // caption teaches nothing.
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(SettingsTheme.sunken)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(SettingsTheme.hairline, lineWidth: 1)
        )
        // One element: the picture and the sentence are one fact,
        // and read apart the strip is an unnamed image.
        .accessibilityElement(children: .combine)
    }

    /// A picture of the user's own menu bar with the mark in it —
    /// the prototype's answer to "where did the app go", and the
    /// reason it beats a bare glyph beside a sentence: the thing
    /// the user has to find is the mark IN a menu bar, so the
    /// picture has to contain one.
    ///
    /// The mark is the real menu-bar image, template-flagged, so
    /// what they match against the strip up top is the same
    /// artwork rather than an SF Symbol standing in for it. The
    /// two blank glyphs beside it stand for whatever else the
    /// user has up there; they are deliberately shapeless.
    private var menuBarStrip: some View {
        HStack(spacing: 11) {
            Spacer(minLength: 0)
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(SettingsTheme.plateInk.opacity(0.28))
                    .frame(width: 9, height: 9)
            }
            Group {
                if let icon = BrandAssets.menuBarIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(SettingsTheme.plateInk)
            .padding(4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SettingsTheme.accent, lineWidth: 2)
            )
            Text(menuBarClock)
                .font(.system(size: 10).monospaced())
                .foregroundStyle(
                    SettingsTheme.plateInk.opacity(0.45)
                )
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(SettingsTheme.previewPlate)
    }

    /// The real time, formatted as this locale writes it. A
    /// picture of a menu bar with a made-up clock in it is a
    /// picture of somebody else's Mac.
    private var menuBarClock: String {
        Date.now.formatted(date: .omitted, time: .shortened)
    }

    /// Deictic on purpose — "this" points at the mark drawn beside
    /// it, which is on this page. The retired coach mark's own
    /// sentence said "in here" about a menu bar the user had to
    /// find first.
    /// Names what Settings is FOR rather than listing what sits
    /// behind the mark (owner, 2026-08-12). "Settings and your
    /// shortcuts" was a contents label — and a wrong one, since
    /// the shortcuts ARE Settings — where a user standing in
    /// front of a menu-bar icon wants to know why they would ever
    /// click it.
    private var menuBarBody: String {
        L(
            "onboarding.ready.menu_bar",
            "Click the KiwiDesk mark up in your menu bar to open "
                + "Settings, where you change your layouts, "
                + "shortcuts and everything else."
        )
    }

    /// The old body told the user to "apply a preset for your
    /// setup", which became false the moment first run started
    /// seeding one: the Starter setup is already applied and
    /// already chosen for their screens.
    ///
    /// Where the app lives moved OUT of this paragraph and into
    /// `menuBarIdentity`, beside the mark it names (#828) — said
    /// in both places it was the same sentence twice, and the
    /// version with the picture is the one a user can match.
    private var doneBody: String {
        L(
            "onboarding.ready.body",
            "KiwiDesk is managing your windows now, with a setup "
                + "chosen for your screens."
        )
    }
}
