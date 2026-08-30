import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The closing tour card (#678, #828, #888).
    var done: some View {
        OnboardingPage(
            title: L(
                "onboarding.ready.title",
                "You're ready to go"
            ),
            body1: doneBody,
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

    /// The one place the running app asks for a star.
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

    private var starProse: String {
        L(
            "onboarding.ready.star_hint",
            "KiwiDesk is free and open source — %1$@ helps "
                + "other people find it."
        )
    }

    private var starLabel: String {
        L("onboarding.ready.star_link", "a star on GitHub")
    }

    /// Visual representation of the menu-bar icon location (#828).
    private var menuBarIdentity: some View {
        VStack(spacing: 0) {
            menuBarStrip
            Text(menuBarBody)
                .font(.system(size: 13.5))
                .foregroundStyle(SettingsTheme.ink2)
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
        .accessibilityElement(children: .combine)
    }

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
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(SettingsTheme.previewPlate)
    }

    private var menuBarClock: String {
        Date.now.formatted(date: .omitted, time: .shortened)
    }

    private var menuBarBody: String {
        L(
            "onboarding.ready.menu_bar",
            "Click the KiwiDesk icon up in your menu bar to open "
                + "Settings, where you change your layouts, "
                + "shortcuts and everything else."
        )
    }

    private var doneBody: String {
        L(
            "onboarding.ready.body",
            "KiwiDesk is managing your windows now, with a setup "
                + "chosen for your screens."
        )
    }
}
