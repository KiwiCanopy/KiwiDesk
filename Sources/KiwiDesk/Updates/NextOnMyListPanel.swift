import KiwiDeskCore
import SwiftUI

/// "Next on my list" under the Highlights card in What's new
/// (#1813 ruling): a plain card, dated, its items as the owner
/// wrote them — English, like the changelog — and a Discord link.
struct NextOnMyListPanel: View {
    let next: NextOnMyList

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                label
                Spacer(minLength: 0)
                Text(asOf)
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsTheme.ink3)
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(next.items.enumerated()), id: \.offset) {
                    UpdateNotesEntryText(
                        text: $0.element,
                        version: nil,
                        size: 13
                    )
                }
            }
            UpdateNotesLink(
                title: L(
                    "update.window.next_discord",
                    "Follow along and share ideas on Discord"
                ),
                url: SupportLinks.discord
            )
            .padding(.top, 3)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(SettingsTheme.card))
        .overlay(shape.strokeBorder(SettingsTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var label: some View {
        Label {
            Text(L("update.window.next_on_my_list", "Next on my list"))
                .textCase(.uppercase)
                .tracking(0.9)
        } icon: {
            Image(systemName: "list.bullet")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(SettingsTheme.ink2)
        .accessibilityAddTraits(.isHeader)
    }

    /// The day the list was written, read in UTC like it is stored.
    private var asOf: String {
        var style = Date.FormatStyle.dateTime.month(.wide).day()
        style.timeZone = .gmt
        return L(
            "update.window.next_as_of",
            "As of %1$@",
            next.asOf.formatted(style)
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
}
