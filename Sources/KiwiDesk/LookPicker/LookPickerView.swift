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
    /// The ground the last step left, drawn opaque under the incoming
    /// one until it is covered, so two grounds never meet half-faded.
    @State private var groundUnder: Int?
    @State private var swapProgress: CGFloat = 1
    @State private var swapSide: CGFloat = 1

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
            if reveal.drop != .hidden {
                LookPickerDrop(
                    stage: reveal.drop,
                    faded: reveal.dropIn,
                    target: dropPoint
                )
            }
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
            backdrop
            LookPickerRow(model: model, geometry: geometry)
            LookPickerCaption(model: model, geometry: geometry)
        }
        .frame(
            width: geometry.screen.width,
            height: geometry.screen.height,
            alignment: .topLeading
        )
    }

    /// The look's own colour ground at the backdrop's strength with a
    /// soft vignette (owner, prototype 2026-11-26); a click on
    /// it closes, as Esc does. #3478 lays the look's picture here.
    private var backdrop: some View {
        ZStack {
            ZStack {
                if let under = groundUnder, model.cards.indices.contains(under)
                {
                    ground(model.cards[under].painted(over: model.settings))
                }
                ground(selectedSettings)
                    .drawingGroup()
                    .modifier(
                        LookPickerSwapIn(
                            progress: swapProgress,
                            side: swapSide
                        )
                    )
            }
            .onChange(of: model.selection) { old, new in
                groundUnder = old
                swapSide = new > old ? 1 : -1
                swapProgress = 0
                withAnimation(reduceMotion ? nil : LookPickerRow.spring) {
                    swapProgress = 1
                }
            }
            RadialGradient(
                colors: [.clear, SettingsTheme.visionVeil.opacity(0.25)],
                center: .center,
                startRadius: geometry.screen.width * 0.2,
                endRadius: geometry.screen.width * 0.6
            )
        }
        .frame(width: geometry.screen.width, height: geometry.screen.height)
        .contentShape(Rectangle())
        .onTapGesture { model.handle(.escape, repeated: false) }
        .accessibilityHidden(true)
    }

    private func ground(_ settings: TilingSettings) -> some View {
        LookGround(
            settings: settings,
            reach: geometry.screen.height * 2,
            stage: .backdrop
        )
    }

    private var selectedSettings: TilingSettings {
        model.selected?.painted(over: model.settings) ?? model.settings
    }
}

/// The card speaks for the picker: the look's name, its line and
/// its place, adjusted by a swipe, worn by the default action.
struct LookPickerCardSpeech: ViewModifier {
    @ObservedObject var model: LookPickerModel

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.selected.map(LookPickerText.name) ?? "")
            .accessibilityValue(model.spokenSelection ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.handle(.step(1), repeated: false)
                case .decrement: model.handle(.step(-1), repeated: false)
                @unknown default: break
                }
            }
            .accessibilityAction { model.wearSelected() }
    }
}
