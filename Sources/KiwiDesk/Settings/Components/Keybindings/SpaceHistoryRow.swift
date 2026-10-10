import KiwiDeskCore
import SwiftUI

/// Focus ▸ Space history (#1655): a compact menu naming the current
/// behaviour — two peers, neither an "off" — in the shortcut rows'
/// shape: the menu in their recorder column, its "Applies to"
/// control in their reach column. Greyed with its reason on a
/// stored profile saved for one screen, where both choices walk
/// the same history.
struct SpaceHistoryRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // The icon slot every shortcut row reserves (#264).
                Color.clear.frame(width: Self.iconSlot, height: 1)
                // The picker names itself; this is its drawn twin.
                Text(SpaceHistoryWords.title)
                    .accessibilityHidden(true)
                HelpButton(
                    explanation: SpaceHistoryWords.help,
                    subject: SpaceHistoryWords.title
                )
                Spacer()
                reach
                ZStack(alignment: .trailing) {
                    KeyRecorderField.footprint
                    menu
                        .padding(
                            .trailing,
                            KeyRecorderField.iconSlotWidth + 6
                        )
                }
            }
            if oneScreen {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.leading, Self.iconSlot + 8)
            }
        }
    }

    private static let iconSlot: CGFloat = 18

    private var menu: some View {
        Picker(
            SpaceHistoryWords.title,
            selection: $model.config.spaceHistory
        ) {
            ForEach(SpaceHistoryKind.allCases, id: \.self) {
                Text(SpaceHistoryWords.value($0)).tag($0)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.regular)
        .fixedSize()
        .accessibilityLabel(SpaceHistoryWords.title)
        .accessibilityValue(
            SpaceHistoryWords.value(model.config.spaceHistory)
        )
        .modifier(GreyOut(active: oneScreen, help: reason))
    }

    private var oneScreen: Bool { model.spaceHistoryRunsOnOneScreen }

    private var reason: String {
        L(
            "shortcuts.space_history.one_screen",
            "This profile runs on one screen, where both work the "
                + "same."
        )
    }

    @ViewBuilder private var reach: some View {
        if model.offersReachColumn, let reading = model.historyReach() {
            RuleReachControl(
                model: model,
                family: .history,
                app: RuleReachTable<SpaceHistoryKind>.spaceHistoryKey,
                subject: SpaceHistoryWords.title,
                reading: reading,
                value: SpaceHistoryWords.value(model.config.spaceHistory)
            )
        }
    }
}

extension SettingsModel {
    /// The Space history row greys (#1655): the edited stored
    /// profile runs on one screen. The live page edits what every
    /// profile shares, so it never greys.
    var spaceHistoryRunsOnOneScreen: Bool {
        guard let name = editingProfile,
            let count =
                profileSummaries
                .first(where: { $0.name == name })?.count
        else { return false }
        return !SpaceHistoryKind.choiceMatters(screens: count)
    }
}

/// What the Space history row is called and how its value reads —
/// one home for the row, the diff pill and the checklist.
@MainActor
enum SpaceHistoryWords {
    static var title: String {
        L("shortcuts.space_history", "Space history")
    }

    static var help: String {
        L(
            "shortcuts.space_history.choice_help",
            "%1$@: each screen remembers its own Spaces, and going "
                + "back or forward changes the Space on the screen you "
                + "are working on. %2$@: one history across every "
                + "screen, so going back may take you to another "
                + "screen. With one screen, both work the same.",
            value(.perScreen),
            value(.allScreens)
        )
    }

    static func value(_ kind: SpaceHistoryKind) -> String {
        switch kind {
        case .perScreen:
            L("shortcuts.space_history.per_screen", "Per screen")
        case .allScreens:
            L("shortcuts.space_history.all_screens", "All screens")
        }
    }
}
