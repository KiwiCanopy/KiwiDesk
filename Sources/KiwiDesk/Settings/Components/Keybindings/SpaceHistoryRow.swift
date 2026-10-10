import KiwiDeskCore
import SwiftUI

/// Focus ▸ Space history (#1655): which history the two rows below
/// it walk, stored like the shortcuts — the shared value or the
/// edited profile's own, through the row's "Applies to" checklist.
/// Greyed on a stored profile saved for one screen, where both
/// choices walk the same history.
struct SpaceHistoryRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SegmentedPicker(
                    SpaceHistoryWords.title,
                    selection: $model.config.spaceHistory,
                    options: SpaceHistoryKind.allCases.map {
                        (SpaceHistoryWords.value($0), $0)
                    },
                    help: SpaceHistoryWords.help
                )
                .modifier(GreyOut(active: oneScreen, help: reason))
                Spacer(minLength: 8)
                reach
            }
            if oneScreen {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            "shortcuts.space_history.help",
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
