import KiwiDeskCore
import SwiftUI

/// One screen's column on the tour's Spaces step (#3294): the
/// screen's name as the heading, its Spaces as cards below.
struct OnboardingScreenColumn: Identifiable, Equatable {
    let id: String
    let screen: String
    let cards: [OnboardingSpaceCard]
}

/// The Spaces step's cards in screen columns, left to right: one
/// screen takes the page's width, several scroll sideways under the
/// strip's edge fade. A new pick redraws the cards with the stagger.
struct OnboardingScreenColumns: View {
    let columns: [OnboardingScreenColumn]
    let settings: TilingSettings
    let restsOnAppear: Bool
    /// Changes with each pick, so the cards play again.
    let revision: Int

    /// A column's width beside others: two fit the tour's page.
    static let columnWidth: CGFloat = 238
    static let gap: CGFloat = 12

    var body: some View {
        Group {
            if columns.count == 1, let only = columns.first {
                column(only, startingAt: 0)
            } else {
                SidewaysStrip<String, _>(run: run, followed: nil) {
                    HStack(alignment: .top, spacing: Self.gap) {
                        ForEach(Array(columns.enumerated()), id: \.1.id) {
                            index,
                            screen in
                            column(screen, startingAt: offset(of: index))
                                .frame(width: Self.columnWidth)
                        }
                    }
                }
            }
        }
        .id(revision)
    }

    private var run: StripRun {
        StripRun(
            lengths: columns.map { _ in Self.columnWidth },
            gap: Self.gap,
            depth: 64
        )
    }

    /// The stagger continues across columns, left to right.
    private func offset(of index: Int) -> Int {
        columns.prefix(index).reduce(0) { $0 + $1.cards.count }
    }

    private func column(
        _ screen: OnboardingScreenColumn,
        startingAt first: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRowHeader(text: screen.screen)
            ForEach(Array(screen.cards.enumerated()), id: \.1.id) {
                index,
                card in
                OnboardingSpaceRow(
                    card: card,
                    settings: settings,
                    delay: OnboardingView.stagger(first + index),
                    restsOnAppear: restsOnAppear
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(screen.screen)
    }
}
