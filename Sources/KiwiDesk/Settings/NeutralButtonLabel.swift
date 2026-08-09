import SwiftUI

extension View {
    /// Paints a bordered button's LABEL in ordinary ink instead
    /// of the window's accent.
    ///
    /// The twin of `neutralMenuLabel()`, for the other control
    /// style that colours its label from the tint. A
    /// `.buttonStyle(.bordered)` button draws its title — and any
    /// SF Symbol beside it — in the tint, so once #678 turn 16b
    /// tinted the window kiwi (`SettingsTheme.accent`) every
    /// bordered button in Settings became green text: "Add app
    /// rule", "Add application", "Fit to layout gaps" and
    /// eighteen more.
    ///
    /// Same principle as the menu twin, and the reason both exist
    /// as named modifiers rather than as local fixes: **the
    /// accent belongs on control FILLS** — a toggle track, a
    /// selected segment, a prominent Save — **never on text.** A
    /// bordered button is a bordered *surface* with a label on
    /// it; the surface is the control, the words are not.
    ///
    /// Not for every button:
    ///
    /// - A `role: .destructive` button draws its label in the
    ///   system red, which is the warning and must survive.
    ///   Neutralising one would paint a delete action in the
    ///   same ink as a save.
    /// - `.borderedProminent` is a filled control, so its accent
    ///   IS the fill this rule protects. Leave it alone.
    /// - A button that resolves its own tint per state
    ///   (`KeyRecorderField`) already decides this question and
    ///   is exempt — see `SettingsBorderedSealTests`'
    ///   `borderedExempt` map, which is the one copy of who may
    ///   skip this.
    ///
    /// `.tint` and not only `.foregroundStyle`, for the reason
    /// `neutralMenuLabel()` states: the label of an AppKit-backed
    /// control follows the tint, and a `foregroundStyle` alone
    /// does not reach it. Both are set so the pair covers the
    /// SwiftUI-drawn and AppKit-drawn halves of one label.
    ///
    /// A bordered action button does not call this directly any
    /// more: `settingsActionButton()` seals the style and this
    /// neutralisation into one call (#771), so the only direct
    /// call sites left are non-bordered labels the tint reaches
    /// anyway — today the one text-labelled `.borderless`
    /// breadcrumb. `SettingsBorderedSealTests` pins the bordered
    /// half (no raw `.buttonStyle(.bordered)` outside its
    /// `borderedExempt` map) and `SettingsLabelNeutralityTests`
    /// enumerates every direct use of this modifier with the
    /// style it sits on.
    func neutralButtonLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
