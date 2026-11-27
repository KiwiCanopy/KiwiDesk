import Foundation
import KiwiDeskCore
import SwiftUI

/// A screen card's number (#3647 ▸ lane 2): a pull-down at the start
/// of its header, neutral since the accent is the Main role's, and
/// never truncated. An unnumbered screen's face says what it gets.
struct ScreenNumberBadge: View {
    @ObservedObject var model: SettingsModel
    let display: Display

    var body: some View {
        let face = Self.face(model.screenNumber(of: display))
        Menu {
            ScreenNumberItems(model: model, display: display)
        } label: {
            Text(face)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .menuTriggerHover()
        .fixedSize()
        .accessibilityLabel(L("monitor_card.number.ax", "Screen number"))
        .accessibilityValue(face)
    }

    /// "Screen N", or what an unnumbered screen gets.
    static func face(_ number: Int?) -> String {
        guard let number else {
            return L("monitor_card.number.unnumbered", "Gets a new Space")
        }
        return L("monitor_card.number_badge", "Screen %1$d", number)
    }
}

/// Why a screen holding a number draws whole: the number's split
/// would put an area under the minimum window size there (#3647 ▸
/// no-fit ruling). Its own element, outside any dim.
struct ScreenUnsplitCaption: View {
    let number: Int
    let axis: ScreenAreaCut.Axis

    var body: some View {
        Text(Self.text(number: number, axis: axis))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func text(number: Int, axis: ScreenAreaCut.Axis) -> String {
        switch axis {
        case .sideBySide:
            L(
                "monitor_card.number.unsplit.side_by_side",
                "Screen %1$d\u{2019}s areas would be narrower than the "
                    + "minimum window size here, so this screen isn\u{2019}t "
                    + "split.",
                number
            )
        case .stacked:
            L(
                "monitor_card.number.unsplit.stacked",
                "Screen %1$d\u{2019}s areas would be shorter than the "
                    + "minimum window size here, so this screen isn\u{2019}t "
                    + "split.",
                number
            )
        }
    }
}

/// The badge's items, which the card's menu ends with too: a number
/// for each screen, checkmarked where it is this screen's, then
/// Don't Number This Screen.
struct ScreenNumberItems: View {
    @ObservedObject var model: SettingsModel
    let display: Display

    var body: some View {
        let current = model.screenNumber(of: display)
        ForEach(1...max(model.screenNumberCount, 1), id: \.self) { number in
            Toggle(
                L("monitor_card.number.use", "Use as Screen %1$d", number),
                isOn: Binding(
                    get: { current == number },
                    set: { _ in model.useScreenNumber(number, for: display) }
                )
            )
            // A number whose split cannot fit here greys (#3647).
            .disabled(
                current != number
                    && !model.screenNumberFits(number, for: display)
            )
        }
        Divider()
        Toggle(
            L("monitor_card.number.none", "Don't Number This Screen"),
            isOn: Binding(
                get: { current == nil },
                set: { _ in model.leaveUnnumbered(display) }
            )
        )
        .disabled(current != nil && !model.canLeaveUnnumbered(display))
    }
}
