import SwiftUI

/// The mode-reveal wash (#760): flipping the header segment to
/// Power User briefly washes the surfaces the flip inserted —
/// the same transient accent wash the search reveal trained,
/// decaying to nothing — while the durable "what is advanced"
/// answer is the accent-tinted frame
/// (`SettingsTheme.containerStrokeModeGated` at
/// `modeGatedStrokeOpacity`): the mode's own colour at reduced
/// strength, never a second hue, with the weight step keeping a
/// hue-free channel.
///
/// Form settled by a `ui-designer` consult (2026-08-09), against
/// the shared vocabulary: a border bloom is a halo, which this
/// app reserves for "this input is armed"; a transient accent
/// border collides with `HomeCard`'s hover stroke; the wash is
/// the one form already meaning "the thing you're looking for is
/// here". It paints the header/title band alone, so a card's
/// live preview never renders through an accent tint that
/// misrepresents the colours it pictures.
///
/// No timer here: `SettingsModel.flipSettingsMode` owns the one
/// timeline, and the environment value's removal IS the fade
/// trigger — the same one-writer shape `SearchRevealFlash`
/// argues, for the same latch-proofing reason.
private struct ModeRevealActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a mode reveal is showing. Mounted once, in
    /// `SettingsView`'s chrome, from
    /// `SettingsModel.modeRevealActive` — above BOTH panes, so
    /// Home cards and in-area surfaces read the same window.
    var settingsModeReveal: Bool {
        get { self[ModeRevealActiveKey.self] }
        set { self[ModeRevealActiveKey.self] = newValue }
    }
}

/// Paints the wash behind a mode-gated container's title band
/// while a reveal is active. `gated` is the same flag that picks
/// the container's stroke weight — derived from the site's own
/// offer predicate evaluated at `.simple`, so the wash and the
/// weight cannot point at different content.
private struct ModeRevealWash: ViewModifier {
    let gated: Bool
    @Environment(\.settingsModeReveal) private var active
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    private var washed: Bool { gated && active }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: SettingsReveal.cornerRadius
                )
                .fill(
                    SettingsTheme.accent.opacity(
                        washed ? SettingsReveal.peakOpacity : 0
                    )
                )
                .padding(-SettingsReveal.bleed)
            }
            // Arriving is instant, leaving eases out. Reduce
            // Motion drops the cross-fade, not the affordance —
            // the wash still shows flat for the same ≈1.2 s
            // (the timeline's hold absorbs the fade) and simply
            // disappears, the split `SearchRevealFlash` makes.
            .animation(fadeOut, value: washed)
    }

    private var fadeOut: Animation? {
        guard !reduceMotion, !washed else { return nil }
        return .easeOut(duration: SettingsReveal.fade)
    }
}

extension View {
    /// The wash half of the mode-gated pairing. Mount on the
    /// container's title band — never the whole card — beside
    /// the stroke-weight ternary that reads the same flag.
    func modeRevealWash(_ gated: Bool) -> some View {
        modifier(ModeRevealWash(gated: gated))
    }
}
