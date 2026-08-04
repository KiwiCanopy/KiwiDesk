import KiwiDeskCore
import SwiftUI

/// Home (#678 turn 9): the card grid that replaced the sidebar
/// as the only navigator. Two scope groups — This Profile /
/// Whole App — of answer-carrying cards; Simple shows the eight
/// first-week cards and Power User inserts the other four at stable
/// positions. The adaptive grid gives the digest's 4→3→2 column
/// steps from the card's own min/max width, so the window
/// survives whatever slot the tiler gives it.
struct HomeScreen: View {
    @ObservedObject var model: SettingsModel
    /// Restores focus to the card whose area was just popped
    /// (turn 20: leaving a sub-view returns to the originating
    /// row).
    @FocusState private var focusedCard: SettingsDestination?
    /// The 14c banner's visibility, read per mount through the
    /// model's defaults seam so a test-constructed Home never
    /// consults the runner's real domain.
    @State private var firstRunVisible = false

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 240, maximum: 360),
                spacing: 16
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if firstRunVisible {
                    HomeFirstRunBanner(
                        model: model,
                        visible: $firstRunVisible
                    )
                }
                group(
                    L(
                        "home.group.this_profile",
                        "This Profile"
                    ),
                    cards: offered(HomeCardOrder.thisProfile)
                )
                group(
                    L("home.group.whole_app", "Whole App"),
                    cards: offered(HomeCardOrder.wholeApp)
                )
            }
            .padding(
                [.horizontal, .bottom],
                SettingsMetrics.paneInset
            )
            // Home had NO top gutter: the area panes get theirs
            // from `SettingsView`'s scroll content margin, which
            // this screen never passes through, so the first
            // group heading sat flush under the header hairline
            // and the grid read as cramped (owner, 2026-08-04).
            // Larger than the panes' inset on purpose — a
            // small-caps heading needs air above it to read as a
            // heading rather than as a caption on the bar.
            .padding(.top, 24)
        }
        .onAppear {
            firstRunVisible = HomeFirstRunState.shouldShow(
                model.preferences
            )
            if let last = model.nav.homeReturnFocus {
                focusedCard = last
                model.nav.homeReturnFocus = nil
            }
        }
    }

    private func offered(
        _ group: [SettingsDestination]
    ) -> [SettingsDestination] {
        HomeCardOrder.offered(
            group,
            mode: model.settingsMode,
            displayCount: model.displays.count,
            editingStoredProfile: model.editingStoredProfile
        )
    }

    @ViewBuilder private func group(
        _ title: String,
        cards: [SettingsDestination]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Small-caps, tracked, green: the prototype's group
            // label. A monospaced face at caption2 with real
            // letter spacing, because uppercase text set solid is
            // what makes a heading read as shouting rather than
            // as a rule over the cards.
            Text(title)
                .font(
                    .system(
                        size: 10,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
                .tracking(1.3)
                .foregroundStyle(SettingsTheme.groupHeading)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(cards) { destination in
                    HomeCard(
                        model: model,
                        destination: destination,
                        spotlighted: model.profileSummaries
                            .isEmpty
                            && destination == .profiles,
                        open: { push(destination) }
                    )
                    .focused($focusedCard, equals: destination)
                }
            }
        }
    }

    private func push(_ destination: SettingsDestination) {
        model.nav.homeReturnFocus = destination
        model.destination = destination
    }
}
