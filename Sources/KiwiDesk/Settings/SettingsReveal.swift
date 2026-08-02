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

/// A live flash: which anchor id, plus a token bumped once per
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

private struct SettingsRevealTargetKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The flash in progress, keyed by anchor id (a
    /// `SettingsControl.id`). Compared by each anchored view
    /// against its own id; nil while nothing is being revealed.
    var settingsFlash: SettingsFlash? {
        get { self[SettingsFlashKey.self] }
        set { self[SettingsFlashKey.self] = newValue }
    }

    /// The anchor id a reveal is heading for, standing from the
    /// moment the request is applied until its flash ends — so a
    /// `SettingsDisclosure` holding that control can expand
    /// before the scroll driver's re-issued `scrollTo` lands.
    /// One writer and one clearer, both in `SettingsView`;
    /// drawers only read it.
    var settingsRevealTarget: String? {
        get { self[SettingsRevealTargetKey.self] }
        set { self[SettingsRevealTargetKey.self] = newValue }
    }
}

/// The scroll ids an inline drawer wants **hoisted to its
/// enclosing section's top** (#610). A hoisted `SettingsDisclosure`
/// contributes its own `SettingsControl`; the nearest
/// `SettingsSection` collects the list and mounts a
/// `searchScrollAnchor` marker per id above its heading, then
/// consumes the value so an outer section never re-collects it.
///
/// The point of routing it through a preference rather than a
/// call-site parameter: the marker's id is the drawer's OWN
/// control by construction, so a hoisted drawer's scroll id and
/// its wash id are the same control with no second list to keep in
/// step — the same "seal it, don't guard it" the `fileprivate`
/// halves buy for the co-located pair (#573). The section
/// auto-discovers whichever drawer is mounted, so the shared
/// surface-free `advancedColors` drawer needs no static parent.
///
/// Known limit: a hoisted drawer with no enclosing
/// `SettingsSection` publishes to nobody, mounts no marker and
/// scrolls nowhere — a nonsensical placement (an inline drawer's
/// premise is that it lives in a section card), but a silent one,
/// so keep hoisted drawers inside a section.
struct HoistedRevealAnchorsKey: PreferenceKey {
    static let defaultValue: [SettingsControl] = []
    static func reduce(
        value: inout [SettingsControl],
        nextValue: () -> [SettingsControl]
    ) {
        value.append(contentsOf: nextValue())
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
/// Stateless by design. An earlier cut held the opacity in
/// `@State` and ran the hold-then-fade inside a `.task(id:)`,
/// which re-washed a card every time the user navigated back to
/// it: `.task(id:)` fires on *appear* as well as on change, and
/// the model's value outlived the reveal that set it. Now the
/// environment value IS the "on" state, its removal IS the fade
/// trigger, and the driver in `SettingsView` owns the single
/// timeline — nothing here can be left latched.
private struct SearchRevealFlash: ViewModifier {
    let anchor: String
    @Environment(\.settingsFlash) private var flash
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    private var isMine: Bool { flash?.anchor == anchor }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: SettingsReveal.cornerRadius
                )
                .fill(
                    Color.accentColor.opacity(
                        isMine ? SettingsReveal.peakOpacity : 0
                    )
                )
                .padding(-SettingsReveal.bleed)
            }
            // Arriving is instant, leaving eases out. Reduce
            // Motion drops the cross-*fade*, not the affordance:
            // a flat tint shown and then removed is not motion,
            // so the wash still appears for the same ≈1.2 s and
            // simply disappears — the same split `HoverChip`
            // makes.
            .animation(fadeOut, value: isMine)
    }

    private var fadeOut: Animation? {
        guard !reduceMotion, !isMine else { return nil }
        return .easeOut(duration: SettingsReveal.fade)
    }
}

// MARK: - The raw halves
//
// `fileprivate` on purpose, and it is the whole design (#573).
//
// A reveal needs two things on the view tree: a scroll
// destination (`.id`) and a wash. Feed them a hand-written
// String and two mistakes become available, both SILENT — a
// literal or mistyped id is a destination no search result
// points at, and one half alone is a flash with nowhere to
// scroll (or the reverse). Nothing crashes; the hit just lands
// nowhere.
//
// Taking the ids from a `SettingsControl` closes both, so the
// three typed modifiers below are the only way in and these two
// cannot be reached from another file at all. That is strictly
// better than a source-scan guard, which can only notice the
// mistake after someone writes it.
extension View {
    /// Tags this view as the scroll destination for `anchor` —
    /// a `SettingsControl.id`, never display text (Appearance
    /// renders "Color" six times at once; ids are stable and
    /// unique per co-mounted view by construction). A one-line
    /// wrapper over `.id()` on purpose: it names the intent and
    /// keeps the identity decision in one place to revisit.
    fileprivate func searchAnchor(
        _ anchor: String
    ) -> some View {
        id(anchor)
    }

    /// Paints the reveal wash while `anchor` is the flashed one.
    fileprivate func searchFlash(
        _ anchor: String
    ) -> some View {
        modifier(SearchRevealFlash(anchor: anchor))
    }
}

// MARK: - The typed surface

extension View {
    /// The whole pairing for a **self-anchoring control** — a
    /// bespoke recognition control that is its own scroll target,
    /// with no header/card split to place the two halves across
    /// (`GapRow`'s slider rows, the "Show it in" bar toggles).
    /// Wash and target are the same rect: there is no expanded
    /// content below to tint by accident, which is the only
    /// reason the two container shapes split them at all.
    ///
    /// A second invariant falls out of applying the pair at the
    /// control's outermost point: the wash lands OUTSIDE any
    /// `GreyOut` in the subtree by construction rather than by
    /// call-site care, so a hit on a gated control still flashes
    /// at full strength (see `SearchRevealFlash`).
    func searchAnchored(
        _ control: SettingsControl
    ) -> some View {
        self.searchFlash(control.id).searchAnchor(control.id)
    }

    /// The container shapes' half of the pair: the scroll
    /// destination, on the whole card, OUTSIDE its chrome so
    /// `scrollTo(anchor: .top)` lands on the card's edge and not
    /// inside its padding. Pairs with `searchFlashHeader`.
    func searchAnchorCard(
        _ control: SettingsControl
    ) -> some View {
        searchAnchor(control.id)
    }

    /// The container shapes' other half: the wash, on the header
    /// alone. Flashing the whole card would tint its content too
    /// — for a drawer, the expanded interior. Pairs with
    /// `searchAnchorCard`.
    func searchFlashHeader(
        _ control: SettingsControl
    ) -> some View {
        searchFlash(control.id)
    }

    /// A **hoisted scroll target** for a drawer whose scroll id is
    /// lifted to the top of its enclosing section (#610).
    ///
    /// An `.inline` `SettingsDisclosure` lives inside a section
    /// card, below that section's heading. Anchoring its own body
    /// makes `scrollTo(anchor: .top)` land the bare drawer label
    /// at the viewport top and scroll the heading that names it
    /// off screen — the disembodiment the #277 top-alignment
    /// ruling exists to prevent. So the drawer keeps its wash
    /// (`searchFlashHeader`, on its own label) but gives up its
    /// scroll id, publishing its control through
    /// `HoistedRevealAnchorsKey`; its enclosing `SettingsSection`
    /// collects that and mounts this zero-size marker at its top.
    /// `scrollTo` then aligns the section's top edge — heading
    /// first — and the drawer label still washes below it.
    ///
    /// Scroll-only, so the pair is split across two views (this
    /// marker scrolls, the drawer label washes) — but over the
    /// same control by construction, because the marker's id comes
    /// from the drawer's own published control, not a second list.
    /// Confined to the container shapes by
    /// `SettingsAnchorPrimitiveTests`, the same seal the paired
    /// halves carry.
    func searchScrollAnchor(
        _ control: SettingsControl
    ) -> some View {
        searchAnchor(control.id)
    }
}
