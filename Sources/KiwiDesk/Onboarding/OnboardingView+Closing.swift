import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    // The separate-Spaces recommendation page retired with #888:
    // Desktop→profile bindings are keyed to the main display's
    // Desktop now, so they are well-defined under the macOS
    // default and there is nothing to recommend against.

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
            // The bottom line is the GUIDE, and it is the
            // card's only DESTINATION (owner + `ui-designer`,
            // 2026-08-26 — originally "only link", amended the
            // same day when the owner ruled the star ask in:
            // `starLine` is not a destination the reader needs,
            // it is the one thing the tour may ask for, and it
            // lives in the content's quiet tier rather than in
            // this footer slot).
            //
            // It replaced "Tiled before? Open Settings", which
            // cost the card more than it bought. That hint
            // sorted the reader by experience — and its false
            // converse told anyone who is NOT a beginner that
            // they DO need Settings today — while offering a
            // third destination on a screen whose menu-bar card
            // already teaches the durable route to Settings (the
            // icon they will still be using on day 30, against a
            // one-time button in a window that never comes
            // back). It also argued with the paragraph above it,
            // which said Settings could wait.
            //
            // Dropping it EXTENDS #678 Phase 4 pass 11 rather
            // than contradicting it: that pass moved Return off
            // Open Settings because this app's position is that
            // Settings is for people who want to dig deeper, and
            // a bottom line still offering Settings was that
            // ruling being argued with in a quieter voice.
            // Nobody is stranded — the picture above names
            // Settings and where it lives, the tour reopens FROM
            // Settings, and `KiwiDesk.open_settings()` is
            // bindable.
            //
            // The frame arrives RAW, slot intact:
            // `LinkedCaption` draws the label AT `%1$@`, so
            // formatting it in first leaves the sentence with
            // nothing to draw at, which is how the first cut
            // shipped the words with no link under them.
            hint: GuideLink.prose,
            hintLeads: true,
            hintLink: .init(
                label: GuideLink.label,
                action: GuideLink.open
            )
        ) {
            menuBarIdentity
            Toggle(
                L(
                    "onboarding.ready.open_at_login",
                    "Start KiwiDesk at login"
                ),
                isOn: $model.openAtLogin
            )
            .toggleStyle(.checkbox)
            .onboardingCard()
            starLine
        } action: {
            Button(L("onboarding.ready.start", "Start using it")) {
                model.commitLoginItemThen { model.onFinish() }
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    // The quiet paragraph under the login card is GONE (owner +
    // `ui-designer`, 2026-08-26), and both halves of it went for
    // reasons worth keeping.
    //
    // Its opener named Settings and what it holds, which is the
    // menu-bar card directly above saying the same thing a second
    // time — and that card says it beside a PICTURE, which is the
    // version that teaches.
    //
    // What was left after that clause went — "If this is your
    // first tiling manager, you do not need Settings today" —
    // sorted the reader before it reassured them. It made
    // beginner-against-experienced the organizing idea of the
    // last thing the tour says, and it has a false converse: a
    // reader who is NOT a beginner is told by implication that
    // they DO need Settings today. Nothing on this screen needs
    // to know which reader it has.
    //
    // The promise it carried is not lost, it is just no longer
    // spoken: the card says the app is already managing windows
    // with a setup chosen for the screens, and the default action
    // says "Start using it". A reader who is told to start is not
    // also wondering whether there is homework.
    //
    // The pointer moved INTO the footer, and keeps its weight
    // there: this page passes `hintLeads`, which draws the hint
    // at 13 pt on `ink2` rather than the other four screens'
    // 12.5 pt `ink3`. That honours the 2026-08-12 ruling — the
    // guide line draws at body weight because it is the last
    // thing the tour says — inside the footer slot rather than
    // reversing it, and it makes this screen's hint deliberately
    // louder than the four that only say what happens if you do
    // nothing.

    /// The star ask, once, at the moment the app has just
    /// delivered its first win (owner, 2026-08-26 — the 1.1
    /// launch decision).
    ///
    /// This is the ONE place the running app asks for a star,
    /// and its one-shot shape is the argument: the tour never
    /// comes back on its own, so the ask cannot become a nag —
    /// which the brand's "no annoying notifications" promise
    /// forbids. The permanent, quiet copy lives in General ▸
    /// About's ask row; recurring surfaces (menu bar, banners)
    /// stay closed to it.
    ///
    /// The quiet tier (12.5 pt, `ink3`), not the footer's: the
    /// footer hint is the card's one DESTINATION (the guide, its
    /// own comment above), and this line must not compete with
    /// it — a reader who skips every caption loses nothing they
    /// need. `LinkedCaption` for the same reasons the footer
    /// uses it: cursor affordance, and the link rides inside the
    /// one localized frame at its own specifier so a translation
    /// places it.
    private var starLine: some View {
        let parts = LinkedCaption.split(frame: starProse)
        return LinkedCaption(
            leading: parts.0,
            linkTitle: starLabel,
            trailing: parts.1,
            navigate: {
                NSWorkspace.shared.open(SupportLinks.gitHub)
            },
            pointSize: 12.5,
            ink: NSColor(SettingsTheme.ink3)
        )
    }

    /// The sentence, carrying `%1$@` where the link's name goes.
    /// "Other people", not "users" — the reader is being asked a
    /// favor for people like themselves, not for a metric.
    private var starProse: String {
        L(
            "onboarding.ready.star_hint",
            "KiwiDesk is free and open source — %1$@ helps "
                + "other people find it."
        )
    }

    /// A NOUN, as `GuideLink.label` is — the sentence around it
    /// carries the verb, so a translation can put the
    /// destination wherever its word order wants it.
    private var starLabel: String {
        L("onboarding.ready.star_link", "a star on GitHub")
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
                // line in the fixed 560 pt window (owner, on
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
            // Illustration, not text: it is part of the PICTURE
            // of a menu bar, which is why it is drawn at 0.45 of
            // the plate ink rather than at a contrast-measured
            // pairing — and why VoiceOver must not read a clock
            // in the middle of the sentence beside it.
            Text(menuBarClock)
                .font(.system(size: 10).monospaced())
                .foregroundStyle(
                    SettingsTheme.plateInk.opacity(0.45)
                )
                .accessibilityHidden(true)
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
            // "icon", not "mark": `config-vocabulary.md` rules
            // `mark` as the on-window state glyph, and this
            // corpus already calls the menu-bar one an icon
            // (`shortcuts.menu_bar_icon`,
            // `brand.menu_bar_icon.a11y`).
            "Click the KiwiDesk icon up in your menu bar to open "
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
