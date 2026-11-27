import Foundation
import KiwiDeskCore
import SwiftUI

/// Screens spatial arrangement diagram with screen cards and follows-main
/// tray (#678 Phase 3).
struct ScreensPicture: View {
    @ObservedObject var model: SettingsModel
    let rows: ScreensFamilyRows
    @Binding var selection: ScreenSelection?
    /// The area giving way in an open Adjust… popover.
    var givingWay: Set<ScreenSelection> = []
    /// The pane a menu's Split or Merge hands focus to.
    var paneFocus: ScreenSelection? = nil
    var act: (ScreenAreaAction) -> Void = { _ in }

    /// The height the screens are fitted to; the picture itself
    /// grows past it to hold what the fit puts under the cards, so
    /// it never scrolls up and down (#3697).
    private static let canvasHeight: CGFloat = 248
    /// Room inside the clip for a risen card's shadow and the main
    /// card's glow.
    private static let inset = SettingsTheme.hoverShadowRadius
    private static let standBand: CGFloat = 16
    @State private var width: CGFloat = 0

    var body: some View {
        let canvas = CGSize(
            width: max(0, width - Self.inset * 2),
            height: Self.canvasHeight - Self.inset * 2 - footBand
        )
        let layout = arrangement(for: canvas)
        let content = CGSize(
            width: layout.contentSize.width,
            height: layout.contentSize.height + footBand
        )
        let height = Self.height(holding: content.height)
        let origin = ScreenArrangement.origin(
            of: layout.contentSize,
            in: canvas
        )
        // Sideways only, for a desk wider than the page; the page
        // scrolls up and down. Nothing is laid out before the width
        // is measured.
        ScrollView(.horizontal) {
            picture(layout)
                .frame(width: content.width, height: content.height)
                .padding(.leading, origin.x)
                .padding(.top, origin.y)
                .padding(Self.inset)
                .opacity(width > 0 ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: width > 0 ? height : Self.canvasHeight)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
    }

    /// The picture's height for content `contentHeight` tall: the
    /// fitted canvas at least, else all of the content (#3697).
    static func height(holding contentHeight: CGFloat) -> CGFloat {
        max(canvasHeight, contentHeight + inset * 2)
    }

    /// The band under the picture's lowest cards: their stands.
    private var footBand: CGFloat { Self.standBand }

    /// Scaled screen stand footer (#758, owner ruling 2026-08-04,
    /// 2026-08-09).
    private func stand(cardWidth: CGFloat) -> some View {
        let base = ScreenArrangement.standBase(cardWidth: cardWidth)
        let neck = min(
            max(
                base * SettingsTheme.screenNeckScale,
                SettingsTheme.screenNeckMin
            ),
            SettingsTheme.screenNeckMax
        )
        return VStack(spacing: 0) {
            Rectangle()
                .fill(SettingsTheme.ink3)
                .frame(width: neck, height: 7 + SettingsTheme.hoverRise)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(SettingsTheme.ink3)
                .frame(width: base, height: 5)
        }
        .allowsHitTesting(false)
    }

    private func arrangement(
        for canvas: CGSize
    ) -> ScreenArrangement.Layout {
        ScreenArrangement.layout(
            displays: rows.displays,
            mainID: model.mainDisplay?.id,
            canvas: canvas,
            trayChips: rows.mainSpaces.count,
            splits: model.effectiveSplits
        )
    }

    private func picture(
        _ layout: ScreenArrangement.Layout
    ) -> some View {
        let standing = ScreenArrangement.standing(layout)
        return ZStack(alignment: .topLeading) {
            ForEach(layout.displays) { drawn in
                ScreenCard(
                    model: model,
                    display: drawn.display,
                    rows: rows,
                    size: drawn.rect.size,
                    selection: $selection,
                    givingWay: givingWay,
                    paneFocus: paneFocus,
                    act: act
                )
                .frame(
                    width: drawn.rect.width,
                    height: drawn.rect.height
                )
                // Behind the card and tucked under its edge, so a
                // risen card opens no gap above the neck; only a
                // card whose foot lands on no other card keeps it
                // (#3517 ruling 28).
                .background(alignment: .bottom) {
                    if standing.contains(drawn.id) {
                        stand(cardWidth: drawn.rect.width)
                            .alignmentGuide(.bottom) {
                                $0[.top] + SettingsTheme.hoverRise
                            }
                    }
                }
                .offset(x: drawn.rect.minX, y: drawn.rect.minY)
            }
            if let tray = layout.tray {
                FollowsMainTray(
                    model: model,
                    rows: rows,
                    size: tray.size
                )
                .frame(width: tray.width, height: tray.height)
                .offset(x: tray.minX, y: tray.minY)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}
