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
    var givingWay: ScreenSelection? = nil
    var act: (ScreenAreaAction) -> Void = { _ in }

    private static let canvasHeight: CGFloat = 248
    /// Room inside the clip for a risen card's shadow and the main
    /// card's glow.
    private static let inset = SettingsTheme.hoverShadowRadius
    private static let standBand: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let canvas = CGSize(
                width: proxy.size.width - Self.inset * 2,
                height: Self.canvasHeight - Self.inset * 2
                    - Self.standBand
            )
            let layout = arrangement(for: canvas)
            let origin = ScreenArrangement.origin(
                of: layout.contentSize,
                in: canvas
            )
            ScrollView([.horizontal, .vertical]) {
                picture(layout)
                    .frame(
                        width: layout.contentSize.width,
                        height: layout.contentSize.height
                            + Self.standBand
                    )
                    .padding(.leading, origin.x)
                    .padding(.top, origin.y)
                    .padding(Self.inset)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .center
            )
        }
        .frame(height: Self.canvasHeight)
    }

    /// Scaled screen stand footer (#758, owner ruling 2026-08-04,
    /// 2026-08-09).
    /// The stand's base width under a card `cardWidth` wide, which
    /// `ScreenArrangement.standing` measures a foot by.
    static func standBase(cardWidth: CGFloat) -> CGFloat {
        min(
            max(
                cardWidth * SettingsTheme.screenStandScale,
                SettingsTheme.screenStandMin
            ),
            SettingsTheme.screenStandMax
        )
    }

    private func stand(cardWidth: CGFloat) -> some View {
        let base = Self.standBase(cardWidth: cardWidth)
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
            splits: model.config.settings.displayAreas
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
