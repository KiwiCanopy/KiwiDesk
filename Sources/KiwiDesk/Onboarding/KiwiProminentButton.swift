import SwiftUI

/// The app's primary action: an accent fill with `accentInk` on
/// it, never white (#828).
///
/// `.buttonStyle(.borderedProminent)` picks its own label colour,
/// and on macOS that is white — which measures **2.41:1** on
/// KiwiDesk's kiwi green, under every legibility floor this repo
/// holds itself to. `SettingsTheme.accentInk` exists for exactly
/// this pairing and its docstring says so: "kiwi is a mid-light
/// green, so white on it fails contrast whatever the appearance
/// says." The prototype draws it that way too — `#12251a` on
/// `#8db354` (owner confirmed on device, 2026-08-12).
///
/// A style rather than a `.foregroundStyle` beside each call
/// site: the label colour and the fill are one decision, and
/// paired by hand they are two a site can get half right — the
/// argument `settingsActionButton()` already makes for the
/// bordered rank, one rank down.
///
/// **It lives in `Onboarding/` because its consumers do.** It was
/// filed under `Settings/` for a day, which made it an Onboarding
/// style policed by Settings-named guards — and `gui.md`'s file
/// layout admits section bodies, area widgets and root-composed
/// Settings widgets there, none of which this is. If Settings
/// ever adopts it, it moves to whatever shelf both trees share
/// rather than back to one of them.
///
/// Stated residue, carried in `gui.md` ▸ Colour rather than only
/// here, because the next prominent button is written in that
/// tree and not this one: the floating save pill and Settings'
/// own `.borderedProminent` sites still draw white on kiwi.
/// Same defect, second set of call sites; adopting this style
/// there is its own change and its own eye-confirm.
struct KiwiProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(SettingsTheme.accentInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
                .fill(SettingsTheme.accent)
            )
            // A hair of the accent's own ink for an edge. A flat
            // fill on a near-white page has no boundary of its
            // own, so the button reads as a painted area rather
            // than a raised control — and a darker shade of the
            // fill is the edge that fixes it without coining a
            // second green.
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
                .stroke(
                    SettingsTheme.accentInk.opacity(0.22),
                    lineWidth: 1
                )
            )
            // Pressed and disabled both read through the FILL,
            // which keeps the label's contrast fixed — dimming
            // dark ink on a dimmed green is how a pressed button
            // becomes unreadable at the moment it is clicked.
            .opacity(pressedOrDisabled(configuration) ? 0.72 : 1)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.chipRadius
                )
            )
    }

    private func pressedOrDisabled(
        _ configuration: Configuration
    ) -> Bool {
        configuration.isPressed || !isEnabled
    }
}

extension View {
    /// The primary action of a screen. One per screen: the style
    /// is what says "this is the way forward", and two of them
    /// says neither is.
    ///
    /// Written dot-free, exactly as `settingsActionButton()`
    /// writes its own: the call-site needles count
    /// `.buttonStyle(`, and the seal applying one inside itself
    /// would otherwise read as a styled button in a file with no
    /// button in it.
    func kiwiProminentButton() -> some View {
        buttonStyle(KiwiProminentButtonStyle())
    }
}
