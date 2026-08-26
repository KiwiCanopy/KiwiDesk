import KiwiDeskCore
import SwiftUI

/// How every Settings drawer's header renders (#956).
///
/// One full-width `.plain` `Button` over the row — chevron,
/// label, Spacer — carrying the house hover cue and a chevron
/// that rotates on expand, with the drawer's `accessory` laid
/// out BESIDE that button rather than inside it. The argument
/// for each of those choices is `docs/design-decisions.md`'s,
/// beside the inline-hairline ruling it follows; what belongs
/// here is the seam.
///
/// **The accessory is a sibling of the button, never its
/// child** — the one thing about this file that is not obvious
/// and the one that broke. `SettingsDisclosure` used to hand
/// the accessory to the `DisclosureGroup` label, which the
/// first draft of this style then wrapped whole in the header
/// button: `DesktopsGroup`'s `?` became a control inside a
/// control, so its click toggled the drawer and its name and
/// hint collapsed into the header's one element (code +
/// architect review, 2026-08-24). An accessory slot that may
/// hold a control cannot travel inside `configuration.label`,
/// which is why the style takes it as its own parameter and
/// the row's hit shape stops where it begins.
///
/// The style deliberately takes no CHROME argument: `.inline`
/// and `.card` differ in what surrounds the header, never in
/// how the header behaves, and a drawer that reads as openable
/// in one chrome and not the other is the defect this fixes.
struct SettingsDisclosureStyle<Accessory: View>:
    DisclosureGroupStyle
{
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// What the drawer hides, stated on the row while it is
    /// SHUT — see `summaryText`.
    private let summary: String?
    @ViewBuilder private let accessory: () -> Accessory

    init(
        summary: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.summary = summary
        self.accessory = accessory
    }

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(configuration)
            if configuration.isExpanded {
                configuration.content
            }
        }
    }

    private func header(
        _ configuration: Configuration
    ) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(
                    reduceMotion
                        ? nil : .easeOut(duration: 0.18)
                ) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    chevron(expanded: configuration.isExpanded)
                    configuration.label
                    // The row is the hit target, so it claims
                    // the width the accessory does not.
                    Spacer(minLength: 0)
                    // INSIDE the button, unlike the accessory
                    // beside it. The #956 ruling puts that slot
                    // outside because it may hold a CONTROL, and
                    // a control inside a control loses its click
                    // and its name — a summary is plain text, so
                    // that reason does not reach it. Drawn
                    // outside, the hover pill stopped where the
                    // summary began and those words did not
                    // toggle the drawer they describe (owner,
                    // 2026-08-26).
                    if !configuration.isExpanded { summaryText }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The FULL-ROW ladder (0 → 0.06), not the icon
            // chip's (0.06 → 0.12). A resting fill that works
            // on all three of this style's grounds has to be
            // `Color.primary`-based, and that is achromatic —
            // invisible at a glyph's size, and at row width the
            // one exactly-neutral band in a green-tinted
            // window. The header rests on its chevron and, in
            // `.inline`, on the hairline rule.
            .rowHoverHighlight(cornerRadius: 6, padding: 4)
            // On the BUTTON, not on the `Text` inside it: the
            // button swallows its label's traits, and putting it
            // here is also what reaches the one drawer whose
            // title is not a plain `Text`. Every drawer was
            // absent from the headings rotor until #1021 — the
            // same "too small to find as one" complaint, on the
            // channel no amount of points can answer.
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(
                configuration.isExpanded
                    ? L("settings.disclosure.ax_expanded", "expanded")
                    : L(
                        "settings.disclosure.ax_collapsed",
                        "collapsed"
                    )
            )
            accessory()
        }
    }

    /// **What the drawer hides, at the size of the header it
    /// sits beside.** Five call sites drew this by hand at
    /// `.font(.caption)` — 10 pt, two steps under a 12 pt
    /// header — which is the same drift the header's own tier
    /// came out of in #1021, and it read as an afterthought
    /// rather than as the row's value (owner, 2026-08-26).
    ///
    /// **It stays BESIDE the header rather than becoming a
    /// caption under it**, and that is the ruling rather than
    /// the layout that fell out: this states the drawer's
    /// current VALUE and is gone the moment the drawer opens,
    /// where a caption explains what a thing IS and stays.
    /// Under the header it would add and remove a line on every
    /// toggle, shoving the rows below it, and it would sit
    /// exactly where the drawer's own contents go — reading as
    /// content that failed to hide. macOS states a shut row's
    /// value trailing on the row, which is where it already
    /// was; only the size was wrong.
    ///
    /// SHUT only, here rather than at each call site: four of
    /// the five wrapped their own `if`, and the fifth
    /// (Presets' count) did not, so the rule was a call-site
    /// decision too. Expanded, the summary restates what the
    /// rows below it now say in full.
    ///
    /// `ink3`, NOT the chevron's `ink2` beside it, and the
    /// distinction is the chevron's own argument read the right
    /// way round. That one takes `ink2` because with no resting
    /// fill the chevron IS the row's affordance, and an
    /// affordance outranks the caption tier. This is not an
    /// affordance — it is description, which is exactly what
    /// `ink3` is for, and a whole phrase of it at the chevron's
    /// darkness competes with the title it supports (owner,
    /// 2026-08-26: "too strong"). Nothing new is drawn on this
    /// ground either way, so `SettingsThemeContrastTests`'
    /// pairings are unchanged.
    ///
    /// **Not `.accessibilityHidden`.** It rides inside the
    /// button, so its words compose into the header's NAME —
    /// "Style, Background, Content …" — where before they were
    /// a static text stop of their own. Read aloud the
    /// information survives the move; hidden it would not, and
    /// the button's `.accessibilityValue` is already spent on
    /// expanded/collapsed.
    ///
    /// **No `layoutPriority`.** The label's `Spacer` is greedy,
    /// so a lower priority here starves the summary to zero
    /// width at every size rather than only at narrow ones.
    /// Sharing the squeeze is what `lineLimit(1)` is for: the
    /// summary loses its tail, the title keeps wrapping.
    @ViewBuilder private var summaryText: some View {
        if let summary {
            Text(summary)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
        }
    }

    /// **Sized by the header it marks, never by a number of its
    /// own** (#1021). It takes no `.font` and no scale step, so
    /// it inherits the header's size outright and moves whenever
    /// the header does: about 12 pt against a 12 pt title, and
    /// about 10 pt on the one deliberately-quiet drawer, which
    /// stays quiet. Proportional by construction rather than a
    /// constant that has to be re-tuned every time a header
    /// moves.
    ///
    /// **Weight is the only step it takes.** It wore
    /// `.imageScale(.large)` on top of the inheritance for one
    /// round, which drew the indicator LARGER than the title it
    /// marks — the biggest thing in the row — and that is what
    /// the owner then read as a heavy header (owner,
    /// 2026-08-26). A scale step here is that regression;
    /// `SettingsDisclosureSizeTests` reds on either it or a
    /// `.font(`.
    ///
    /// That is what #956 claimed and did not do. It replaced the
    /// native triangle *because* the system drew it small, then
    /// pinned the replacement at `.footnote` — the smallest step
    /// on the ramp. It bought a hit target, an announcement and
    /// one notch of weight; it never made the indicator bigger,
    /// which is why the complaint came back (ui-designer,
    /// 2026-08-26).
    ///
    /// A concrete ink rather than `.secondary`: the Overrides
    /// footer sets `.foregroundStyle(.secondary)` on the whole
    /// group, and hierarchical styles compound — that one
    /// header drew its cue at secondary-of-secondary (code
    /// review, 2026-08-24).
    ///
    /// `ink2`, not the quieter `ink3` it first took: with no
    /// resting fill the chevron IS the row's resting
    /// affordance, and `ink3` is the caption tier — body copy,
    /// by its own docstring. Row detail outranks a caption
    /// (ui-designer, 2026-08-24).
    private func chevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .fontWeight(.bold)
            .foregroundStyle(SettingsTheme.ink2)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            // The state it encodes is on the button's value, in
            // words; a second reading of the same fact as
            // "chevron.right" is noise.
            .accessibilityHidden(true)
    }
}

extension SettingsDisclosureStyle where Accessory == EmptyView {
    /// A drawer with nothing beside its title.
    init() {
        self.init(accessory: { EmptyView() })
    }
}
