import KiwiDeskCore
import SwiftUI

/// The Space-step picture (#1519, variant C): the shelf's Space
/// items over a desk, the held keys and the two inputs below. The
/// fingers swipe left and the next Space's desk slides in — a
/// different arrangement on a plate of its own, so it never reads
/// as #1656's row panning — then swipe right and the first comes
/// back, so the rest frame at 1 matches the first. The active item
/// moves when each slide commits.
extension GesturePicture {
    struct SpaceStep: View, Animatable {
        var t: CGFloat
        /// The chord in effect; none draws the inputs alone.
        let chord: ScrollChord
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        /// A desk's travel: the plate's width and the gap between.
        private static let travel: CGFloat = 128

        var body: some View {
            let ink = GestureInk(palette: palette)
            let there = gestureEase(gestureStage(t, 0.05, 0.25))
            let back = gestureEase(gestureStage(t, 0.55, 0.75))
            let slide =
                gestureEase(gestureStage(t, 0.2, 0.4))
                - gestureEase(gestureStage(t, 0.7, 0.9))
            let onNext =
                gestureStage(t, 0.28, 0.32) - gestureStage(t, 0.78, 0.82)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ForEach(0..<4, id: \.self) { index in
                    ink.item(Self.item(index), label: "\(index + 1)")
                }
                ink.activeRing(Self.item(1)).opacity(1 - onNext)
                ink.activeRing(Self.item(2)).opacity(onNext)
                desk(ink, windows: Self.deskA)
                    .offset(x: -Self.travel * slide)
                desk(ink, windows: Self.deskB)
                    .offset(x: Self.travel * (1 - slide))
                ink.scrollLegend(chord, swipe: there * (1 - back))
            }
        }

        /// The shelf's Space items, left to right.
        private static func item(_ index: Int) -> CGRect {
            CGRect(x: 6 + 17 * CGFloat(index), y: 3, width: 13, height: 10)
        }

        /// Two windows side by side.
        private static let deskA = [
            CGRect(x: 8, y: 22, width: 50, height: 28),
            CGRect(x: 62, y: 22, width: 50, height: 28),
        ]

        /// One wide window and two stacked beside it.
        private static let deskB = [
            CGRect(x: 8, y: 22, width: 64, height: 28),
            CGRect(x: 76, y: 22, width: 36, height: 12),
            CGRect(x: 76, y: 38, width: 36, height: 12),
        ]

        /// A Space's desk: a faint plate with its windows.
        private func desk(_ ink: GestureInk, windows: [CGRect]) -> some View {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(ink.ink.opacity(0.05))
                    .frame(width: 116, height: 34)
                    .offset(x: 2, y: 19)
                ForEach(Array(windows.enumerated()), id: \.offset) { _, rect in
                    ink.window(rect)
                }
            }
        }
    }
}
