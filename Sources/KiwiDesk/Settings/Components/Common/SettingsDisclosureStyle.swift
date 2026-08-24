import KiwiDeskCore
import SwiftUI

/// How every Settings drawer's header renders (#956).
///
/// The native `DisclosureGroupStyle` puts the only hit target in
/// the triangle, which is both too small to find and too small
/// to hit: System Settings and Finder make the whole disclosure
/// row clickable, so a header that answers only its triangle
/// under-signals ("is this expandable at all?") and then
/// under-delivers when a reader clicks the label anyway (owner
/// live QA, 2026-08-23). The first round — the `.inline`
/// chrome's top hairline — said "different kind of row" without
/// saying "openable"; this round changes the header itself.
///
/// Three things, one seam:
///
/// - **One full-width `Button`**, `.plain`, `.contentShape` over
///   the whole row. One hit area, one focus stop, and Space or
///   Return toggles it because that is what a button does — the
///   `.onTapGesture` alternative leaves two hit mechanisms and a
///   path neither focus nor VoiceOver can see.
/// - **A resting affordance**: the house ambiguous-control cue,
///   `hoverHighlight()` at 0.06 → 0.12, plus a chevron with real
///   weight that rotates 90° on expand.
/// - **The announcement, given back.** A `Button` is not a
///   disclosure triangle, so VoiceOver stops saying whether the
///   drawer is open — the `LinkedCaptionHitTests` lesson, that
///   an AppKit-or-custom control re-earns what its native twin
///   gave free. `.accessibilityValue` carries expanded /
///   collapsed back.
///
/// The style deliberately takes no chrome argument: `.inline`
/// and `.card` differ in what surrounds the header, never in how
/// the header behaves, and a drawer that reads as openable in
/// one chrome and not the other is the defect this fixes.
struct SettingsDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

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
                // The row is the hit target, so it claims the
                // full width even when the label is short.
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityValue(
            configuration.isExpanded
                ? L("settings.disclosure.expanded", "expanded")
                : L("settings.disclosure.collapsed", "collapsed")
        )
    }

    /// Weight is the point: the native triangle is drawn at the
    /// system's own small size, which is what made it easy to
    /// miss beside a column of plain rows.
    private func chevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            // The state it encodes is on the button's value, in
            // words; a second reading of the same fact as
            // "chevron.right" is noise.
            .accessibilityHidden(true)
    }
}
