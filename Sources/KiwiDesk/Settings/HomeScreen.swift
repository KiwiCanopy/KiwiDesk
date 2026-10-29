import KiwiDeskCore
import SwiftUI

/// Main Settings navigation grid screen (#678 turn 9).
struct HomeScreen: View {
    @ObservedObject var model: SettingsModel
    /// Restores focus to previously active card on back navigation (turn 20).
    @FocusState private var focusedCard: SettingsDestination?
    /// Visibility state of first-run guidance banner (14c).
    @State private var firstRunVisible = false
    /// Current window width classification band (17a).
    @Environment(\.settingsWidth) private var band
    /// Whether the cards are in their slots: false only while the
    /// switch's converge has yet to play (#2737 ruling 13).
    @State private var arrived: Bool

    init(model: SettingsModel) {
        self.model = model
        _arrived = State(initialValue: !model.nav.convergePending)
    }

    /// Adaptive grid column count, capped at four with the cards
    /// GROWING into a big screen (owner 2026-08-10): `.adaptive`
    /// cannot say "at most four AND growing", so the count derives
    /// from measured width, with 17a's band as the ceiling —
    /// without it the fit alone reaches four at ~1040 and Home
    /// would step on a threshold of its own.
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

    /// The one top gutter, shared with the height the content must
    /// fill (#1536).
    private static let topGutter: CGFloat = 24

    /// Maximum container width for saturated grid (code review 2026-08-11).
    private var gridCap: CGFloat {
        let columns = CGFloat(SettingsWidthClass.wide.homeColumnCap)
        return columns * 360 + (columns - 1) * 16
            + SettingsMetrics.paneInset * 2
    }

    var body: some View {
        GeometryReader { geo in
            grid(width: geo.size.width, height: geo.size.height)
        }
        .coordinateSpace(name: HomeConverge.space)
        .onAppear {
            arrived = true
            model.nav.convergePending = false
        }
    }

    private func grid(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
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
                    columns: columns(for: width, band: band),
                    first: 0,
                    viewport: CGSize(width: width, height: height)
                )
                group(
                    L("home.group.whole_app", "Whole App"),
                    cards: offered(HomeCardOrder.wholeApp),
                    columns: columns(for: width, band: band),
                    first: offered(HomeCardOrder.thisProfile).count,
                    viewport: CGSize(width: width, height: height)
                )
                // The strip sits at the window's bottom edge when
                // the cards leave room, and scrolls after them when
                // they do not (#1536).
                HomeSupportStrip(model: model)
            }
            // The strip's footer reaches the window's bottom inset
            // exactly: the viewport less the gutters this content
            // already carries, or a short page scrolls by the
            // difference (code review, 2026-09-21).
            .frame(
                minHeight: height - Self.topGutter
                    - SettingsMetrics.paneInset,
                alignment: .top
            )
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
            .padding(.top, Self.topGutter)
        }
        .onAppear {
            firstRunVisible = HomeFirstRunState.shouldShow(
                model.preferences
            )
            // Warm icon cache for ruled apps (#786).
            AppIconCache.shared.warm()
            if let last = model.nav.homeReturnFocus {
                // Cleared either way, restored only where the
                // platform would have moved focus (#991): a slot
                // left full leaks into the next appear.
                if model.nav.navigationMovesFocus {
                    focusedCard = last
                }
                model.nav.homeReturnFocus = nil
            }
        }
    }

    private func offered(
        _ group: [SettingsDestination]
    ) -> [SettingsDestination] {
        HomeCardOrder.offered(
            group,
            editingStoredProfile: model.editingStoredProfile
        )
    }

    @ViewBuilder private func group(
        _ title: String,
        cards: [SettingsDestination],
        columns: [GridItem],
        first: Int,
        viewport: CGSize
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeGroupHeading(title)
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(Array(cards.enumerated()), id: \.element) {
                    offset,
                    destination in
                    HomeCard(
                        model: model,
                        destination: destination,
                        spotlighted: model.profileSummaries
                            .isEmpty
                            && destination == .profiles,
                        open: { push(destination) }
                    )
                    .focused($focusedCard, equals: destination)
                    .modifier(
                        HomeConverge(
                            arrived: arrived,
                            index: first + offset,
                            viewport: viewport
                        )
                    )
                }
            }
        }
    }

    private func push(_ destination: SettingsDestination) {
        model.openFromCard(destination)
    }
}

/// The small-caps heading over a Home group — and over the
/// support strip (#1536), so the page has one heading voice.
struct HomeGroupHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
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
    }
}
