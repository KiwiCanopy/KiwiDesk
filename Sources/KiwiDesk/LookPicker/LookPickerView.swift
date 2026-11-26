import KiwiDeskCore
import SwiftUI

/// The look picker, full screen (#3038 ▸ Ruling 2026-11-23, style
/// E): the selected look's backdrop, the other looks as stripes
/// either side, the card in a frosted frame, its name below — and,
/// once a look is worn, the puddle that opens the real desk.
struct LookPickerView: View {
    @ObservedObject var model: LookPickerModel
    @ObservedObject var reveal: LookPickerReveal
    let geometry: LookPickerGeometry
    @Environment(\.kiwiDeskReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        ZStack {
            picker
                .blur(radius: reveal.blur)
                .mask {
                    LookPickerHole(
                        centre: dropPoint,
                        radius: reveal.holeRadius
                    )
                    .fill(style: FillStyle(eoFill: true))
                }
            if reveal.waveShown {
                LookPickerWave(
                    centre: dropPoint,
                    radius: reveal.holeRadius,
                    rimOnly: reduceTransparency
                )
            }
            // Mounted from the start, so its fall from `.hidden` (drawn
            // as `.above`) animates rather than appearing landed.
            LookPickerDrop(
                stage: reveal.drop,
                faded: reveal.dropIn,
                target: dropPoint
            )
        }
        .frame(width: geometry.screen.width, height: geometry.screen.height)
        .opacity(reveal.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LookPickerText.panelName)
    }

    /// The drop lands on the card's centre, where the wave starts.
    private var dropPoint: CGPoint {
        CGPoint(x: geometry.card.midX, y: geometry.card.midY)
    }

    private var picker: some View {
        ZStack(alignment: .topLeading) {
            LookPickerBackdrop(
                model: model,
                pictures: model.pictures,
                geometry: geometry
            )
            LookPickerRow(model: model, geometry: geometry)
            LookPickerCaption(model: model, geometry: geometry)
        }
        .frame(
            width: geometry.screen.width,
            height: geometry.screen.height,
            alignment: .topLeading
        )
    }
}
