import KiwiDeskCore
import SwiftUI

/// Monitors spatial arrangement diagram with display cards and follows-main
/// tray (#678 Phase 3).
struct MonitorsPicture: View {
    @ObservedObject var model: SettingsModel
    let rows: MonitorsFamilyRows
    @Binding var selection: DisplayID?

    private static let canvasHeight: CGFloat = 240
    private static let inset: CGFloat = 4
    private static let standBand: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let layout = arrangement(
                for: CGSize(
                    width: proxy.size.width - Self.inset * 2,
                    height: Self.canvasHeight - Self.inset * 2
                        - Self.standBand
                )
            )
            ScrollView([.horizontal, .vertical]) {
                picture(layout)
                    .frame(
                        width: layout.contentSize.width,
                        height: layout.contentSize.height
                            + Self.standBand
                    )
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

    /// Scaled display stand footer (#758, owner ruling 2026-08-04,
    /// 2026-08-09).
    private func stand(cardWidth: CGFloat) -> some View {
        let base = min(
            max(
                cardWidth * SettingsTheme.monitorStandScale,
                SettingsTheme.monitorStandMin
            ),
            SettingsTheme.monitorStandMax
        )
        let neck = min(
            max(
                base * SettingsTheme.monitorNeckScale,
                SettingsTheme.monitorNeckMin
            ),
            SettingsTheme.monitorNeckMax
        )
        return VStack(spacing: 0) {
            Rectangle()
                .fill(SettingsTheme.ink3)
                .frame(width: neck, height: 7)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(SettingsTheme.ink3)
                .frame(width: base, height: 5)
        }
        .allowsHitTesting(false)
    }

    private func arrangement(
        for canvas: CGSize
    ) -> MonitorArrangement.Layout {
        MonitorArrangement.layout(
            displays: rows.displays,
            mainID: model.mainDisplay?.id,
            canvas: canvas,
            trayChips: rows.mainSpaces.count
        )
    }

    private func picture(
        _ layout: MonitorArrangement.Layout
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.displays) { drawn in
                DisplayCard(
                    model: model,
                    display: drawn.display,
                    rows: rows,
                    size: drawn.rect.size,
                    selection: $selection
                )
                .frame(
                    width: drawn.rect.width,
                    height: drawn.rect.height
                )
                .overlay(alignment: .bottom) {
                    stand(cardWidth: drawn.rect.width)
                        .alignmentGuide(.bottom) { $0[.top] }
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
