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
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// What the drawer hides, shown trailing while shut.
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
                        .font(SettingsDrawerHeader.tier)
                        .foregroundStyle(SettingsTheme.ink)
                    Spacer(minLength: 0)
                    if !configuration.isExpanded {
                        summaryText
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .rowHoverHighlight(cornerRadius: 6, padding: 4)
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

    /// Summary text shown when shut (`SettingsThemeContrastTests`, #1021).
    @ViewBuilder private var summaryText: some View {
        if let summary {
            Text(summary)
                .font(SettingsDrawerHeader.tier)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
        }
    }

    /// Rotating chevron (`SettingsDisclosureSizeTests`, #956, #1021).
    private func chevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .fontWeight(.bold)
            .foregroundStyle(SettingsTheme.ink2)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .accessibilityHidden(true)
    }
}

extension SettingsDisclosureStyle where Accessory == EmptyView {
    /// A drawer with nothing beside its title.
    init() {
        self.init(accessory: { EmptyView() })
    }
}
