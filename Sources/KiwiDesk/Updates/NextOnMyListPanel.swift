import KiwiDeskCore
import SwiftUI

/// "Next on my list" under the Highlights card in What's new
/// (#1813 ruling): a plain card, dated, its items as the owner
/// wrote them — English, like the changelog — and a Discord link.
struct NextOnMyListPanel: View {
    let next: NextOnMyList
    /// One quiet support line under Discord — never beside an
    /// Install (#1849).
    var asksForSupport = false

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
                title: UpdateNotesEnglish.discord,
                url: SupportLinks.discord
            )
            .padding(.top, 3)
            if asksForSupport {
                UpdateNotesLink(
                    title: UpdateNotesEnglish.support,
                    url: SupportLinks.koFi
                )
            }
        }
        .updateNotesCard()
        .accessibilityElement(children: .contain)
    }

    private var label: some View {
        Label {
            Text(UpdateNotesEnglish.nextOnMyList)
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
        style.locale = UpdateNotesEnglish.locale
        return UpdateNotesEnglish.asOf(next.asOf.formatted(style))
    }
}
