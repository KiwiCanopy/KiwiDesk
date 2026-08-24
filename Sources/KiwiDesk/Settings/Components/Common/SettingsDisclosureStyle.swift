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
/// button: `NativeSpacesGroup`'s `?` became a control inside a
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
    @ViewBuilder private let accessory: () -> Accessory

    init(@ViewBuilder accessory: @escaping () -> Accessory) {
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
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

    /// Weight is the point: the native triangle is drawn at the
    /// system's own small size, which is what made it easy to
    /// miss beside a column of plain rows.
    ///
    /// A concrete ink rather than `.secondary`: the Overrides
    /// footer sets `.foregroundStyle(.secondary)` on the whole
    /// group, and hierarchical styles compound — that one
    /// header drew its cue at secondary-of-secondary (code
    /// review, 2026-08-24).
    private func chevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink3)
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
