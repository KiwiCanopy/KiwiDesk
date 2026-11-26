import KiwiDeskCore
import SwiftUI

/// The picker's backdrop (#3038 ▸ Ruling 2026-11-26): the selected
/// look's layer wiped in from the side the step came from over the
/// layer it replaces, which stays opaque until the wipe lands. A
/// click on it closes, as Esc does.
struct LookPickerBackdrop: View {
    @ObservedObject var model: LookPickerModel
    @ObservedObject var pictures: LookPickerPictures
    let geometry: LookPickerGeometry
    @Environment(\.kiwiDeskReduceMotion) private var reduceMotion
    /// The look the last step left, drawn under the incoming one.
    @State private var under: LookPickerEntry?
    @State private var progress: CGFloat = 1
    /// The latest swap, so only its landing drops `under`.
    @State private var swap = 0

    var body: some View {
        ZStack {
            if let under {
                LookPickerBackdropLayer(
                    entry: under,
                    settings: model.settings,
                    picture: pictures.image(of: under, over: model.settings),
                    geometry: geometry
                )
            }
            LookPickerBackdropLayer(
                entry: model.selected,
                settings: model.settings,
                picture: pictures.image(
                    of: model.selected,
                    over: model.settings
                ),
                geometry: geometry
            )
            .drawingGroup()
            .modifier(
                LookPickerSwapIn(
                    progress: progress,
                    side: CGFloat(model.stepSide)
                )
            )
        }
        .onChange(of: model.selection) { old, _ in
            under = model.cards.indices.contains(old) ? model.cards[old] : nil
            progress = 0
            swap += 1
            let current = swap
            withAnimation(reduceMotion ? nil : LookPickerRow.spring) {
                progress = 1
            } completion: {
                if current == swap { under = nil }
            }
        }
        .frame(width: geometry.screen.width, height: geometry.screen.height)
        .contentShape(Rectangle())
        .onTapGesture { model.handle(.escape, repeated: false) }
        .accessibilityHidden(true)
    }
}

/// One look's backdrop: its picture filling the screen where it
/// carries one (#3478), decoded once at the screen's pixel size and
/// never full size per frame (#3038 ▸ Ruling 2026-11-26); else its
/// colour ground at the backdrop's strength under a soft vignette
/// (owner, prototype 2026-11-26).
struct LookPickerBackdropLayer: View {
    let entry: LookPickerEntry?
    let settings: TilingSettings
    /// The card's decoded picture; nil draws the colour ground.
    var picture: CGImage?
    let geometry: LookPickerGeometry

    var body: some View {
        if let picture {
            Image(decorative: picture, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: geometry.screen.width,
                    height: geometry.screen.height
                )
                .clipped()
        } else {
            colourGround
        }
    }

    private var colourGround: some View {
        ZStack {
            LookGround(
                settings: entry?.painted(over: settings) ?? settings,
                reach: geometry.screen.height * 2,
                stage: .backdrop
            )
            RadialGradient(
                colors: [
                    .clear,
                    SettingsTheme.visionVeil.opacity(Self.vignette),
                ],
                center: .center,
                startRadius: geometry.screen.width * 0.2,
                endRadius: geometry.screen.width * 0.6
            )
        }
    }

    /// The vignette's darkest share at the screen's edge.
    static let vignette = 0.25
}
