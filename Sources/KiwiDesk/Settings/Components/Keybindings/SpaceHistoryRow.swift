import KiwiDeskCore
import SwiftUI

/// Focus ▸ Space history (#1655): one checkbox — a binary is a
/// toggle (`docs/ui-patterns.md`) — shaped like the shortcut rows
/// below it, its "Applies to" control in their reach column. Off
/// keeps a history per screen, the default. Greyed with its reason
/// on a stored profile saved for one screen, where both choices
/// walk the same history.
struct SpaceHistoryRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // The icon slot every shortcut row reserves (#264).
                Color.clear.frame(width: Self.iconSlot, height: 1)
                Toggle(SpaceHistoryWords.shared, isOn: shared)
                    .toggleStyle(.checkbox)
                    .modifier(GreyOut(active: oneScreen, help: reason))
                HelpButton(
                    explanation: SpaceHistoryWords.help,
                    subject: SpaceHistoryWords.shared
                )
                Spacer()
                reach
                KeyRecorderField.footprint
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

    /// On is one history across every screen.
    private var shared: Binding<Bool> {
        Binding(
            get: { model.config.spaceHistory == .allScreens },
            set: {
                model.config.spaceHistory = $0 ? .allScreens : .perScreen
            }
        )
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

    /// The checkbox's label: what turning it on does.
    static var shared: String {
        L(
            "shortcuts.space_history.shared",
            "One Space history across all screens"
        )
    }

    static var help: String {
        L(
            "shortcuts.space_history.shared_help",
            "Each screen remembers the Spaces you visited on it, so "
                + "going back or forward changes the Space on the "
                + "screen you are working on. Turn this on to keep one "
                + "history across every screen instead, so going back "
                + "may take you to another screen. With one screen, "
                + "both work the same."
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
