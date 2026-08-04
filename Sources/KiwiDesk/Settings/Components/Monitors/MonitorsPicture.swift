import KiwiDeskCore
import SwiftUI

/// The Monitors picture (#678 Phase 3, turn 13b): the display
/// cards laid out where the displays actually are, with the
/// follows-main tray hanging off the main one.
///
/// The geometry is `MonitorArrangement`'s and nothing is
/// re-derived here — this view's whole job is to put each drawn
/// rectangle on screen and hand it a card. Both axes scroll,
/// because the arrangement is allowed to exceed the canvas: the
/// scale has a FLOOR (every card stays big enough to drop a chip
/// onto), and honouring that floor on a wide desk is what pushes
/// the picture past the pane.
struct MonitorsPicture: View {
    @ObservedObject var model: SettingsModel
    let rows: MonitorsFamilyRows
    @Binding var selection: DisplayID?

    /// The canvas the arrangement is fitted into. A fixed height
    /// rather than one derived from the arrangement: the pane's
    /// width is only known inside the reader, and a height that
    /// followed the content would move every card on screen each
    /// time a monitor was plugged in.
    private static let canvasHeight: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            let layout = arrangement(
                for: CGSize(
                    width: proxy.size.width,
                    height: Self.canvasHeight
                )
            )
            ScrollView([.horizontal, .vertical]) {
                picture(layout)
                    .frame(
                        width: layout.contentSize.width,
                        height: layout.contentSize.height
                    )
                    .padding(4)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .center
            )
        }
        .frame(height: Self.canvasHeight)
        .background(well)
    }

    /// The desk the displays sit on: a recessed well, so each
    /// card can be the LIGHTER thing on it. Without it the cards
    /// and the section they live in painted the same colour and
    /// the arrangement — the whole point of this area — was a
    /// faint outline on a flat field.
    private var well: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(SettingsTheme.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        SettingsTheme.hairline,
                        lineWidth: 0.5
                    )
            )
    }

    private func arrangement(
        for canvas: CGSize
    ) -> MonitorArrangement.Layout {
        MonitorArrangement.layout(
            displays: rows.displays,
            mainID: model.mainDisplay?.id,
            canvas: canvas
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
                .offset(x: drawn.rect.minX, y: drawn.rect.minY)
            }
            // No gate on the tray: `.mainSpaces` and `.spacePins`
            // are one row family drawn by one picture, and a
            // `showsTray` flag derived from the same resolver arm
            // as the picture itself could never be false — an
            // inert branch, with a wiring needle pinning it
            // (code review, 2026-08-04).
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
