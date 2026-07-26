import SwiftUI

/// Scroll-to + flash for a search hit (#277): the shared timing
/// and the one modifier that paints the flash, so the sidebar
/// driver and every anchored view agree on the choreography.
///
/// Treatment settled by a `ui-designer` consult (2026-07-27): a
/// transient accent **wash**, not a ring and not a pulse. A ring
/// or halo is this app's vocabulary for "this input is armed"
/// (`RecorderButtonChrome`, the search field's focus stroke), so
/// spending it on a passive spotlight would promise a keyboard
/// focus state that has no `FocusState` behind it — worse for
/// VoiceOver than for the eye. A scale/opacity pulse reads
/// bouncy, the same motion the layout schematics rejected.
enum SettingsReveal {
    /// Peak wash opacity. Double the recorder halo's ambient
    /// 0.08, which is calibrated to sit for minutes; this is
    /// calibrated to be noticed once.
    static let peakOpacity = 0.18
    static let cornerRadius: CGFloat = 6
    /// How far the wash bleeds past the anchored content.
    static let bleed: CGFloat = 4
    /// Scroll travel. Longer than the 0.12 s hover/focus
    /// micro-transitions because the displacement is larger,
    /// still short enough to read as a jump-cut.
    static let scroll = 0.3
    /// Layout settle after the scroll, before the flash starts.
    static let settle = 0.1
    /// Flat hold at peak, then the fade — ≈1.2 s total.
    static let hold = 0.3
    static let fade = 0.9

    static func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(seconds * 1_000_000_000)
    }
}

/// A live flash: which anchor, plus a token bumped once per
/// reveal. The token exists so that revealing the *same* anchor
/// twice is a new value — without it the flash's `.task(id:)`
/// would see an unchanged id and never re-fire, so searching the
/// same row again would silently do nothing.
struct SettingsFlash: Equatable {
    let anchor: String
    let token: Int
}

private struct SettingsFlashKey: EnvironmentKey {
    static let defaultValue: SettingsFlash? = nil
}

extension EnvironmentValues {
    /// The flash in progress, keyed by resolved label text.
    /// Compared by each anchored view against its own title; nil
    /// while nothing is being revealed.
    var settingsFlash: SettingsFlash? {
        get { self[SettingsFlashKey.self] }
        set { self[SettingsFlashKey.self] = newValue }
    }
}

/// Paints the reveal wash behind the anchored content while the
/// environment names it.
///
/// Mounted OUTSIDE any `GreyOut` in the anchored subtree,
/// deliberately: `GreyOut` multiplies opacity on its content, so
/// a wash nested inside a dimmed block would compound down to
/// ~0.09 and read as a rendering fault. A hit on a control that
/// some other switch has greyed still deserves a full-strength
/// flash — the user typed a real label, and "grey, don't hide"
/// (§2.7) means it is findable precisely while inert.
private struct SearchRevealFlash: ViewModifier {
    let anchor: String
    @Environment(\.settingsFlash) private var flash
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var opacity: Double = 0
    private var isMine: Bool { flash?.anchor == anchor }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: SettingsReveal.cornerRadius
                )
                .fill(Color.accentColor.opacity(opacity))
                .padding(-SettingsReveal.bleed)
            }
            .task(id: flash) { await run() }
    }

    /// Reduce Motion drops the cross-*fade*, not the affordance:
    /// a flat tint shown and then removed is not motion, so the
    /// wash still appears for the same ≈1.2 s and simply
    /// disappears instead of dissolving — the same split
    /// `HoverChip` already makes.
    private func run() async {
        guard isMine else { return }
        opacity = SettingsReveal.peakOpacity
        try? await Task.sleep(
            nanoseconds: SettingsReveal.nanoseconds(
                SettingsReveal.hold
            )
        )
        guard !reduceMotion else {
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.fade
                )
            )
            opacity = 0
            return
        }
        withAnimation(
            .easeOut(duration: SettingsReveal.fade)
        ) {
            opacity = 0
        }
    }
}

extension View {
    /// Tags this view as the scroll destination for `anchor` —
    /// its own resolved label text. A one-line wrapper over
    /// `.id()` on purpose: it names the intent at ~40 call
    /// sites and keeps the "anchor identity IS the label text"
    /// decision in one place to revisit.
    ///
    /// Goes on the whole card, while `searchFlash` goes on its
    /// header: the scroll lands at the card's top so the group
    /// heading is on screen (a header-less control reads as
    /// disembodied), and the wash marks the heading rather than
    /// washing a whole card in accent.
    func searchAnchor(_ anchor: String) -> some View {
        id(anchor)
    }

    /// Paints the reveal wash while `anchor` is the flashed one.
    func searchFlash(_ anchor: String) -> some View {
        modifier(SearchRevealFlash(anchor: anchor))
    }
}
