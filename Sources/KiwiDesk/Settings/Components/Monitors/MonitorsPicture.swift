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

    /// The breathing room around the picture inside its well.
    ///
    /// SUBTRACTED from the canvas the arrangement is fitted into,
    /// not merely added around it: `layout` fills the canvas it
    /// is handed almost exactly — it fits the displays into
    /// `canvas − trayHeight − trayGap` and then puts the band
    /// back — so padding applied afterwards pushed the content
    /// past the frame by twice this, and the picture scrolled by
    /// a few points on a desk that fits comfortably (owner,
    /// 2026-08-04). A many-display desk still scrolls, which is
    /// the minimum-card floor doing its job.
    private static let inset: CGFloat = 4

    /// The band under the picture that the stands hang into.
    ///
    /// RESERVED, not merely drawn into: a stand hangs past its
    /// card's frame, and the scroll content is sized to the
    /// layout's `contentSize` — so without a band the feet were
    /// clipped off at the content's edge, and the topmost card's
    /// stand was cut where it met the card above it (owner,
    /// 2026-08-04). Subtracted from the canvas that is fitted and
    /// added back to the content frame, so the arrangement keeps
    /// the same room it had and the stands get their own.
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

    /// A neck and a foot under each display, in the hairline the
    /// cards are bordered with — quiet enough that the picture
    /// still reads as an arrangement rather than as furniture.
    ///
    /// SCALED from the card, within bounds. A fixed size was
    /// tried first, on the reasoning that a stand is a real
    /// object of roughly one size whatever the panel above it —
    /// which is true of desks and false of this picture, where a
    /// single display fills the whole canvas and a 34 pt foot
    /// under a 520 pt screen reads as a speck of dirt (owner,
    /// 2026-08-04). The clamp is what stops the same proportion
    /// giving a laptop thumbnail a plinth.
    private func stand(cardWidth: CGFloat) -> some View {
        let base = min(max(cardWidth * 0.38, 44), 190)
        let neck = min(max(base * 0.26, 14), 44)
        return VStack(spacing: 0) {
            Rectangle()
                .fill(SettingsTheme.hairline)
                .frame(width: neck, height: 7)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(SettingsTheme.hairline)
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
                // Drawn BELOW the card and outside its frame, so
                // it costs the card no drop area: the layout
                // floors a card at the size that holds one space
                // chip, and a stand carved out of that would eat
                // into the floor it guarantees. Decoration only —
                // it is what makes a rectangle read as a monitor
                // rather than as a box.
                .overlay(alignment: .bottom) {
                    stand(cardWidth: drawn.rect.width)
                        .alignmentGuide(.bottom) { $0[.top] }
                }
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
