import KiwiDeskCore
import SwiftUI

/// A split card's header (#3697 ▸ owner, ui-designer 2026-11-27):
/// the screen's number badge, name and Main chip in one band across
/// the card's top, above every pane and divider. The badge never
/// truncates and Main outranks the name, which truncates in the
/// middle so a twin keeps its position; a name too narrow to read
/// leaves the band, the card's hover naming it still.
struct ScreenCardBand: View {
    @ObservedObject var model: SettingsModel
    let display: Display

    /// About three letters of the band's caption face: below it a
    /// name names nothing.
    static let nameFloor: CGFloat = 20

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(named: true)
            row(named: false)
        }
        .padding(.horizontal, ScreenCardChips.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(named: Bool) -> some View {
        HStack(spacing: 4) {
            ScreenNumberBadge(model: model, display: display)
                .font(.caption)
                .fixedSize()
                .layoutPriority(3)
            if named {
                Text(model.screenLabel(display))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    // An ideal at the floor, so the named row fits
                    // whenever the floor does and the name truncates.
                    .frame(
                        minWidth: Self.nameFloor,
                        idealWidth: Self.nameFloor,
                        alignment: .leading
                    )
                    .allowsHitTesting(false)
                    // The card's own label names the screen.
                    .accessibilityHidden(true)
            }
            if model.mainDisplay?.id == display.id {
                BadgeChip(label: L("monitor_card.main_badge", "main"))
                    .fixedSize()
                    .layoutPriority(2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .bold()
    }
}
