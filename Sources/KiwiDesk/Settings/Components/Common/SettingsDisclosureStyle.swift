import KiwiDeskCore
import SwiftUI

/// Font tier for drawer header row (`SettingsDisclosureSizeTests`, #1021).
enum SettingsDrawerHeader {
    static let tier: Font = .callout
}

/// Settings drawer header render style (#956).
///
/// Header button is a full-width `.plain` Button with chevron, label, and
/// summary. Accessory view is laid out as a sibling outside the button.
struct SettingsDisclosureStyle<Accessory: View>:
    DisclosureGroupStyle
{
    /// What the drawer hides, shown trailing while shut.
    private let summary: String?
    /// Held open by what it shows: the chevron greys (#1948).
    private let locked: Bool
    @ViewBuilder private let accessory: () -> Accessory

    init(
        summary: String? = nil,
        locked: Bool = false,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.summary = summary
        self.locked = locked
        self.accessory = accessory
    }

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(configuration)
            if configuration.isExpanded || locked {
                configuration.content
            }
        }
    }

    private func header(
        _ configuration: Configuration
    ) -> some View {
        HStack(spacing: 6) {
            SettingsDisclosureButton(
                isExpanded: configuration.$isExpanded,
                locked: locked
            ) {
                configuration.label
                    .font(SettingsDrawerHeader.tier)
                    .foregroundStyle(SettingsTheme.ink)
                Spacer(minLength: 0)
                if !configuration.isExpanded, !locked {
                    summaryText
                }
            }
            accessory()
        }
    }

    /// Summary text shown when shut (`SettingsThemeContrastTests`, #1021).
    @ViewBuilder private var summaryText: some View {
        if let summary {
            Text(summary)
                .font(SettingsDrawerHeader.tier)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
        }
    }
}

extension SettingsDisclosureStyle where Accessory == EmptyView {
    /// A drawer with nothing beside its title.
    init() {
        self.init(accessory: { EmptyView() })
    }
}

/// The one header button every collapsible container draws — the
/// drawer style and `SettingsCollapsibleSection` (#1741): chevron,
/// full-row `.plain` button, hover, header trait, expanded value and
/// the Reduce Motion gate, in one place so none of them forks.
struct SettingsDisclosureButton<Label: View>: View {
    @Binding var isExpanded: Bool
    /// Held open by what it shows (#1948): the one home of that
    /// state — it reads expanded, ignores a press and greys its
    /// chevron, the way a dimmed control says it takes no input.
    /// The caller still shows its content while locked.
    var locked = false
    /// A drawer's header is a heading; a row inside a titled
    /// card (`SettingsCollapsibleSection`) is not.
    var isHeading = true
    @ViewBuilder let label: () -> Label
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button {
            guard !locked else { return }
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: 0.18)
            ) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                chevron
                label()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowHoverHighlight(cornerRadius: 6, padding: 4)
        // Takes no press and no hover while held open.
        .allowsHitTesting(!locked)
        .accessibilityAddTraits(.isHeader)
        .accessibilityRemoveTraits(isHeading ? [] : .isHeader)
        .accessibilityHint(
            locked
                ? L(
                    "settings.disclosure.ax_locked",
                    "Stays open while a row inside differs."
                )
                : ""
        )
        .accessibilityValue(
            isExpanded || locked
                ? L("settings.disclosure.ax_expanded", "expanded")
                : L("settings.disclosure.ax_collapsed", "collapsed")
        )
    }

    /// Rotating chevron (`SettingsDisclosureSizeTests`, #956,
    /// #1021); inherits the header's font tier.
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .fontWeight(.bold)
            .foregroundStyle(locked ? SettingsTheme.ink3 : SettingsTheme.ink2)
            .rotationEffect(.degrees(isExpanded || locked ? 90 : 0))
            .accessibilityHidden(true)
    }
}
