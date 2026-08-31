import KiwiDeskCore
import SwiftUI

/// Main Settings navigation grid screen (#678 turn 9).
struct HomeScreen: View {
    @ObservedObject var model: SettingsModel
    /// Restores focus to previously active card on back navigation (turn 20).
    @FocusState private var focusedCard: SettingsDestination?
    /// Visibility state of first-run guidance banner (14c).
    @State private var firstRunVisible = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// Current window width classification band (17a).
    @Environment(\.settingsWidth) private var band

    /// Adaptive grid column layout up to 4 columns
    /// (owner rulings 2026-08-10, 17a).
    private func columns(
        for width: CGFloat,
        band: SettingsWidthClass
    ) -> [GridItem] {
        let inset = SettingsMetrics.paneInset * 2
        let usable = max(width - inset, 240)
        let fit = Int((usable + 16) / (240 + 16))
        let count = max(1, min(band.homeColumnCap, fit))
        return Array(
            repeating: GridItem(
                .flexible(minimum: 240, maximum: 360),
                spacing: 16
            ),
            count: count
        )
    }

    /// Maximum container width for saturated grid (code review 2026-08-11).
    private var gridCap: CGFloat {
        let columns = CGFloat(SettingsWidthClass.wide.homeColumnCap)
        return columns * 360 + (columns - 1) * 16
            + SettingsMetrics.paneInset * 2
    }

    var body: some View {
        GeometryReader { geo in
            grid(width: geo.size.width)
        }
    }

    private func grid(width: CGFloat) -> some View {
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
                    cards: offered(HomeCardOrder.thisProfile),
                    columns: columns(for: width, band: band)
                )
                group(
                    L("home.group.whole_app", "Whole App"),
                    cards: offered(HomeCardOrder.wholeApp),
                    columns: columns(for: width, band: band)
                )
            }
            .padding(
                [.horizontal, .bottom],
                SettingsMetrics.paneInset
            )
            .frame(maxWidth: gridCap)
            .frame(maxWidth: .infinity, alignment: .center)
            // Home had NO top gutter: the area panes get theirs
            // from `SettingsView`'s scroll content margin, which
            // this screen never passes through, so the first
            // group heading sat flush under the header hairline
            // and the grid read as cramped (owner, 2026-08-04).
            // Larger than the panes' inset on purpose — a
            // small-caps heading needs air above it to read as a
            // heading rather than as a caption on the bar.
            .padding(.top, 24)
            // The flip's reflow (#760): Simple's order is a
            // subsequence of Power User's, so the motion is pure
            // insertion (in) or removal (out) — legible either
            // way, and the way out is the plain fade the issue
            // asks for, never a highlight. Reduce Motion drops
            // the reflow; the wash and border weight still
            // answer.
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(
                        duration: SettingsReveal.scroll
                    ),
                value: model.settingsMode
            )
        }
        .onAppear {
            firstRunVisible = HomeFirstRunState.shouldShow(
                model.preferences
            )
            // Warm icon cache for ruled apps (#786).
            AppIconCache.shared.warm()
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
        cards: [SettingsDestination],
        columns: [GridItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
