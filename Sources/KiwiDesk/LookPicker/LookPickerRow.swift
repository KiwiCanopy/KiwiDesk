import KiwiDeskCore
import SwiftUI

/// The looks as one carousel (owner, prototype 2026-11-26): one view
/// per look, keyed by the look, placed at `LookPickerGeometry.slot`,
/// so a step grows the next stripe into the card and shrinks the card
/// into a stripe on one spring. The frosted frame is the seat and
/// never moves; a step that wraps lays the row out at once and fades
/// it in (ui-designer, 2026-11-26).
struct LookPickerRow: View {
    @ObservedObject var model: LookPickerModel
    let geometry: LookPickerGeometry
    @Environment(\.kiwiDeskReduceMotion) private var reduceMotion
    @State private var opacity: Double = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            seat.zIndex(90)
            ForEach(shown, id: \.self) { index in
                let d = index - model.selection
                LookPickerRowItem(
                    entry: model.cards[index],
                    settings: model.settings,
                    spaceLabels: model.spaceLabels,
                    geometry: geometry,
                    distance: d
                )
                .onTapGesture {
                    if d == 0 {
                        model.wearSelected()
                    } else {
                        model.select(index)
                    }
                }
                .zIndex(d == 0 ? 100 : Double(50 - abs(d)))
            }
        }
        .frame(
            width: geometry.screen.width,
            height: geometry.screen.height,
            alignment: .topLeading
        )
        .opacity(opacity)
        .animation(
            reduceMotion || model.wrapped ? nil : Self.spring,
            value: model.selection
        )
        .onChange(of: model.selection) {
            guard model.wrapped else { return }
            opacity = 0
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: Self.wrapFade)
            ) {
                opacity = 1
            }
        }
    }

    /// The looks drawn: the card, the stripes each side shows, and one
    /// more past each edge to slide in from it.
    private var shown: [Int] {
        let left = geometry.shownStripes(side: -1) + 1
        let right = geometry.shownStripes(side: 1) + 1
        let low = max(model.selection - left, 0)
        let high = min(model.selection + right, model.cards.count - 1)
        return low <= high ? Array(low...high) : []
    }

    /// The card's frosted frame, which the selected look grows into.
    private var seat: some View {
        let frame = geometry.frame
        let shape = RoundedRectangle(
            cornerRadius: LookPickerGeometry.frameRadius
        )
        return Color.clear
            .glassChrome(
                in: shape,
                enabled: true,
                variant: .regular,
                tint: nil,
                fallback: AnyShapeStyle(.regularMaterial)
            )
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

    /// The carousel's one spring, for the size and the shift alike.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// A wrapped row's fade-in.
    static let wrapFade: TimeInterval = 0.18
}

/// One look in the row, `distance` places from the selection: its
/// scene laid out once at card size, scaled and clipped to its slot,
/// so a step changes only the scale, the clip and the shade.
private struct LookPickerRowItem: View {
    let entry: LookPickerEntry
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]
    let geometry: LookPickerGeometry
    let distance: Int

    var body: some View {
        let card = geometry.card
        let rect = geometry.slot(for: distance)
        let scale = rect.height / max(card.height, 1)
        let radius =
            distance == 0
            ? LookPickerGeometry.cardRadius : LookPickerGeometry.stripeRadius
        let shade =
            distance == 0
            ? 0 : LookPickerGeometry.stripeShade(abs(distance) - 1)
        LookCardScene(
            settings: entry.painted(over: settings),
            spaceLabels: spaceLabels,
            scale: geometry.scale,
            height: card.height
        )
        .frame(width: card.width, height: card.height)
        .overlay(SettingsTheme.visionVeil.opacity(shade))
        .mask(
            RoundedRectangle(cornerRadius: radius / scale)
                .frame(width: rect.width / scale, height: card.height)
        )
        .scaleEffect(scale)
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .shadow(
            color: SettingsTheme.visionVeil.opacity(distance == 0 ? 0 : 0.55),
            radius: 9
        )
        .position(x: rect.midX, y: rect.midY)
        .accessibilityHidden(true)
    }
}
