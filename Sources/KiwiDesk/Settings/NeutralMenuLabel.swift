import SwiftUI

extension View {
    /// Paints a borderless menu's LABEL in ordinary ink instead
    /// of the window's accent.
    ///
    /// `.menuStyle(.borderlessButton)` renders its label — the
    /// title text and any glyphs beside it — in the accent
    /// colour. That was tolerable while the accent was the
    /// system's, because a blue value on a neutral row still read
    /// as text; once #678 turn 16b tinted the window kiwi
    /// (`SettingsTheme.accent`), every one of these became green
    /// text, and several of them sit on the green-washed chips
    /// that the same tint produces. Green on green is what the
    /// owner could not read (2026-08-04).
    ///
    /// The principle underneath, which is why this is a named
    /// modifier rather than six local fixes: **the accent belongs
    /// on control FILLS** — a toggle track, a selected segment, a
    /// prominent Save — **never on text that is merely naming the
    /// current value.** A menu that says which profile is being
    /// edited is a value, not an action.
    ///
    /// `.tint` and not only `.foregroundStyle`, because the label
    /// of an AppKit-backed control follows the tint; a
    /// `foregroundStyle` alone does not reach it. Both are set:
    /// the pair covers the SwiftUI-drawn and AppKit-drawn halves
    /// of the same label, and neither is redundant on every
    /// macOS.
    ///
    /// Pinned by `SettingsThemeWiringTests` — every
    /// `.menuStyle(.borderlessButton)` in the Settings tree must
    /// carry this.
    func neutralMenuLabel() -> some View {
        tint(SettingsTheme.ink)
            .foregroundStyle(SettingsTheme.ink)
    }
}
