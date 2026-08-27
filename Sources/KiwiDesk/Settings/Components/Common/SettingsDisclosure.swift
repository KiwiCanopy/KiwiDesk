import SwiftUI

/// The one way a Settings drawer renders (#277): a
/// `DisclosureGroup` that owns the anchor pairing part 1 left as
/// a call-site convention — `searchFlashHeader` on the label,
/// `searchAnchorCard` on the whole group, OUTSIDE any card chrome —
/// plus expansion, so a reveal targeting a control *inside* a
/// collapsed drawer opens it before the scroll lands.
///
/// The containment question ("is the reveal target one of
/// mine?") is answered by the `SettingsDrawer` value the call
/// site already mounts — its nested children declarations —
/// never a parent column in the catalog. A direct hit on the
/// drawer's own label does NOT auto-expand: the header is
/// visible and highlighted, and opening it is one honest click
/// (part-1 design call).
///
/// Two chromes, matching the two shapes the tree uses: `.inline`
/// for a drawer inside a `SettingsSection` card (Gaps, the bar
/// colour drawers), `.card` for a standalone drawer that paints
/// its own card (the three "Advanced" drawers). The card chrome
/// anchors outside its padding so `scrollTo(anchor: .top)` lands
/// on the card's edge, not 12 pt inside it — the mistake the
/// part-1 comment block in `SettingsReveal` existed to spell
/// out.
///
/// An `.inline` drawer sits *below* its section's heading, so
/// anchoring its own body would scroll that heading off screen
/// (#610). Such a drawer sets `scrollHoisted`: it gives up its
/// scroll id and publishes its control through
/// `HoistedRevealAnchorsKey`, which its enclosing `SettingsSection`
/// turns into a top-of-section `searchScrollAnchor` marker, so the
/// reveal lands the section — heading first — while the drawer
/// keeps its own wash.
struct SettingsDisclosure<Content: View, Accessory: View>: View {
    /// What SURROUNDS the header — never how it is drawn (#1021).
    ///
    /// It used to carry a `font:` payload, and that is what the
    /// owner was looking at: one component drew its title at
    /// four tiers, and SEVEN of the fifteen drawers were drawn
    /// SMALLER than the rows they head. A header quieter than
    /// its own contents is an inverted hierarchy, and pushing
    /// the choice out to each call site is what let it drift
    /// that far. Both chromes now draw ONE tier, which is the
    /// part that must not drift back —
    /// `SettingsDisclosureSizeTests` holds it.
    ///
    /// That tier is `.callout` at semibold: 12 pt, a point
    /// UNDER the `.body` rows it heads, carrying the header on
    /// weight rather than on size. It went to `.headline` (13
    /// pt semibold) first, and the owner read the result as
    /// heavy on the two pages that carry seven of the fifteen
    /// drawers between them. Note there is no "bigger"
    /// available above either: macOS's ramp goes body 13 →
    /// headline 13 at weight 0.4 → title3 15, so below 15
    /// "bigger" and "weightier" are the SAME edit, and the only
    /// genuine size step is `title3` — `SettingsGroupHeader`'s
    /// tier, which would outrank the section title an inline
    /// drawer sits INSIDE (owner, 2026-08-26).
    enum Chrome {
        /// Inside a section card, under a hairline rule.
        case inline
        /// Standalone: 12 pt padding and its own card
        /// background.
        case card
    }

    private let control: SettingsControl
    private let childIDs: Set<String>
    private let chrome: Chrome
    /// `.inline` only: the scroll id is hoisted to the enclosing
    /// section's top (#610), so this drawer keeps its wash but
    /// gives up its own `searchAnchorCard`, publishing its control
    /// through `HoistedRevealAnchorsKey` for the section to anchor.
    /// A `.card` drawer paints its own card and anchors it, so it
    /// ignores this.
    private let scrollHoisted: Bool
    /// The drawer's presence is mode-gated — it would leave the
    /// page in Simple (#760). Heavier `.card` stroke, and the
    /// mode-reveal wash marks the label; call sites derive it
    /// from their own offer predicate evaluated at `.simple`.
    private let modeGated: Bool
    /// Call-site expansion state, for a drawer with its own
    /// rules (Gaps force-expands while its values are mixed);
    /// nil means this view owns it.
    private let externalExpansion: Binding<Bool>?
    @State private var internalExpansion = false
    /// What the drawer hides, drawn beside the header while it
    /// is shut. `SettingsDisclosureStyle.summaryText` owns the
    /// tier and the shut-only rule; a call site hands it the
    /// words and nothing else.
    ///
    /// **Those words are user-facing**, so a call site passes an
    /// `L()` result.
    ///
    /// **A summary is a PHRASE saying what is inside, never a
    /// bare count (#1028).** Since #1021 it renders inside the
    /// header button, so its text composes into that button's
    /// accessibility NAME and therefore into its headings-rotor
    /// entry: a lone number announces as an unlabelled digit
    /// ("Other setups 12, collapsed, heading") where its
    /// siblings announce "Background, content, indicator, sizes,
    /// symbol style". The placement is correct and is not what
    /// should change — the string is. `PresetsSection` was the
    /// one call site that passed a count; it now passes nothing,
    /// which is the other legal answer.
    private let summary: String?
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let accessory: () -> Accessory
    @Environment(\.settingsRevealTarget)
    private var revealTarget

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline,
        isExpanded: Binding<Bool>? = nil,
        scrollHoisted: Bool = false,
        modeGated: Bool = false,
        summary: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.control = drawer.control
        self.childIDs = drawer.childIDs
        self.chrome = chrome
        self.scrollHoisted = scrollHoisted
        self.modeGated = modeGated
        self.summary = summary
        self.externalExpansion = isExpanded
        self.content = content
        self.accessory = accessory
    }

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline,
        isExpanded: Binding<Bool>? = nil,
        scrollHoisted: Bool = false,
        modeGated: Bool = false,
        summary: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where Accessory == EmptyView {
        self.init(
            drawer,
            chrome: chrome,
            isExpanded: isExpanded,
            scrollHoisted: scrollHoisted,
            modeGated: modeGated,
            summary: summary,
            content: content,
            accessory: { EmptyView() }
        )
    }

    var body: some View {
        switch chrome {
        case .inline:
            // Hoisted (#610): publish this control so the enclosing
            // section mounts the scroll marker at its top, and DON'T
            // anchor here — a second candidate would let `scrollTo`
            // land the bare drawer at the top, the very bug. The
            // wash stays, on the label inside `group`. Emitting only
            // from `.inline` also means `scrollHoisted` on a `.card`
            // drawer is inert rather than a double anchor.
            if scrollHoisted {
                inlineRuled.preference(
                    key: HoistedRevealAnchorsKey.self,
                    value: [control]
                )
            } else {
                inlineRuled.searchAnchorCard(control)
            }
        case .card:
            group
                .padding(12)
                .background(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.sectionRadius
                    )
                    .fill(SettingsTheme.card)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius:
                                SettingsTheme.sectionRadius
                        )
                        .strokeBorder(
                            modeGated
                                ? SettingsTheme.accent.opacity(
                                    SettingsTheme
                                        .modeGatedStrokeOpacity
                                )
                                : SettingsTheme.hairline,
                            lineWidth: modeGated
                                ? SettingsTheme
                                    .containerStrokeModeGated
                                : SettingsTheme.containerStroke
                        )
                    )
                )
                .searchAnchorCard(control)
        }
    }

    /// The inline form leads with a thin rule (owner
    /// 2026-08-10: the App Bar's Style accordion was nearly
    /// overlooked among plain rows) — the prototype draws
    /// every inline disclosure row with a top border, so the
    /// rule is the row's "I am a different kind of row"
    /// signal, matching the card rows around it without
    /// promoting the drawer to a card.
    private var inlineRuled: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsTheme.hairline.frame(height: 1)
            group
        }
        .padding(.top, 4)
    }

    private var group: some View {
        DisclosureGroup(isExpanded: expansion) {
            // The Sunken interior: an expanded drawer's contents
            // sit in a well one step inside the card, so what the
            // disclosure REVEALS is legible as a nested thing
            // rather than as more of the card it opened from.
            //
            // The `VStack` is load-bearing, not layout taste: a
            // caller may hand this a bare `ForEach`, and SwiftUI
            // applies modifiers on a `ForEach` PER CHILD — the
            // Motion drawer shipped every toggle, a caption and
            // a lone `Divider` each in its own well before this
            // wrapper made the well one (owner caught it on
            // screen, 2026-08-10).
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(10)
            // Fill AND hairline: `sunken` on `card` is
            // 1.08:1, so a fill-only well says nothing about
            // being nested — which is the well's whole job.
            .background(
                RoundedRectangle(
                    cornerRadius:
                        SettingsTheme.disclosureRadius
                )
                .fill(SettingsTheme.sunken)
                .overlay(
                    RoundedRectangle(
                        cornerRadius:
                            SettingsTheme.disclosureRadius
                    )
                    .strokeBorder(SettingsTheme.hairline)
                )
            )
        } label: {
            // The wash goes on the label alone; flashing the
            // group would tint the expanded contents too — the
            // whole-card wash the treatment exists to avoid.
            //
            // The accessory is NOT in here (#956): the style
            // makes this label the content of the header's
            // button, and an accessory may be a control —
            // `DesktopsGroup`'s `?` is. It travels to the
            // style separately and is drawn beside the button.
            Text(control.text)
                .font(SettingsDrawerHeader.tier.weight(.semibold))
                .searchFlashHeader(control)
                // The mode-reveal wash shares the label band the
                // search wash uses (#760), for the same reason:
                // a whole-group wash would tint the interior.
                .modeRevealWash(modeGated)
        }
        // The header is a full-row button with a resting cue
        // and its own expanded/collapsed announcement (#956) —
        // `SettingsDisclosureStyle` carries the argument. Every
        // drawer takes it, in both chromes.
        .disclosureGroupStyle(
            SettingsDisclosureStyle(
                summary: summary,
                accessory: accessory
            )
        )
        // Reads only — the reveal fields keep one writer and
        // one clearer (`SettingsView`); an observer that also
        // cleared could blank a request before the scroll
        // driver ran (the part-1 #326 bug).
        .onChange(of: revealTarget) { _, target in
            expand(revealing: target)
        }
        .onAppear { expand(revealing: revealTarget) }
    }

    private var expansion: Binding<Bool> {
        externalExpansion ?? $internalExpansion
    }

    private func expand(revealing target: String?) {
        guard childIDs.contains(target ?? "") else { return }
        expansion.wrappedValue = true
    }
}
