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
            if reveal.dropShown {
                LookPickerDrop(
                    landed: reveal.dropLanded,
                    splashed: reveal.dropSplashed,
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
            stripes(side: -1)
            stripes(side: 1)
            card
            LookPickerCaption(model: model, geometry: geometry)
        }
        .frame(
            width: geometry.screen.width,
            height: geometry.screen.height,
            alignment: .topLeading
        )
    }

    /// The look's own colour ground with a soft vignette; a click on
    /// it closes, as Esc does. #3478 lays the look's picture here.
    private var backdrop: some View {
        ZStack {
            LookGround(
                settings: selectedSettings,
                reach: geometry.screen.height * 0.9
            )
            RadialGradient(
                colors: [.clear, SettingsTheme.visionVeil.opacity(0.45)],
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

    private var selectedSettings: TilingSettings {
        model.selected?.painted(over: model.settings) ?? model.settings
    }

    @ViewBuilder
    private func stripes(side: Int) -> some View {
        let available =
            side < 0
            ? model.selection
            : model.cards.count - model.selection - 1
        let rects = geometry.stripes(side: side, available: available)
        // The far ones first, so each nearer stripe lies on top.
        ForEach(Array(rects.enumerated()).reversed(), id: \.offset) {
            item in
            let k = item.offset
            let rect = item.element
            let index = model.selection + side * (k + 1)
            LookPickerStripe(
                entry: model.cards[index],
                settings: model.settings,
                spaceLabels: model.spaceLabels,
                geometry: geometry,
                shade: LookPickerGeometry.stripeShade(k)
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture { model.select(index) }
        }
    }

    private var card: some View {
        let frame = geometry.frame
        let shape = RoundedRectangle(
            cornerRadius: LookPickerGeometry.frameRadius
        )
        return ZStack {
            Color.clear.glassChrome(
                in: shape,
                enabled: true,
                variant: .regular,
                tint: nil,
                fallback: AnyShapeStyle(.regularMaterial)
            )
            LookCardScene(
                settings: selectedSettings,
                spaceLabels: model.spaceLabels,
                scale: geometry.scale,
                height: geometry.card.height
            )
            .frame(width: geometry.card.width, height: geometry.card.height)
            .clipShape(
                RoundedRectangle(cornerRadius: LookPickerGeometry.cardRadius)
            )
        }
        .frame(width: frame.width, height: frame.height)
        .shadow(
            color: SettingsTheme.visionVeil.opacity(0.5),
            radius: 40,
            y: 30
        )
        .offset(x: frame.minX, y: frame.minY)
        .onTapGesture { model.wearSelected() }
        .modifier(LookPickerCardSpeech(model: model))
    }
}

/// One stripe: the whole look scaled down, darker further out.
private struct LookPickerStripe: View {
    let entry: LookPickerEntry
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]
    let geometry: LookPickerGeometry
    let shade: Double

    var body: some View {
        let card = geometry.card.size
        let fit = geometry.stripeSize.height / max(card.height, 1)
        LookCardScene(
            settings: entry.painted(over: settings),
            spaceLabels: spaceLabels,
            scale: geometry.scale,
            height: card.height
        )
        .frame(width: card.width, height: card.height)
        .scaleEffect(fit)
        .frame(
            width: geometry.stripeSize.width,
            height: geometry.stripeSize.height
        )
        .overlay(SettingsTheme.visionVeil.opacity(shade))
        .clipShape(
            RoundedRectangle(cornerRadius: LookPickerGeometry.stripeRadius)
        )
        .shadow(color: SettingsTheme.visionVeil.opacity(0.55), radius: 9)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

/// The card speaks for the picker: the look's name, its line and
/// its place, adjusted by a swipe, worn by the default action.
private struct LookPickerCardSpeech: ViewModifier {
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
