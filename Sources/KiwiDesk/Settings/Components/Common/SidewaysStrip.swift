import KiwiDeskCore
import SwiftUI

/// The one sideways scroller of a Settings strip (#2987): the
/// platform's scroller, the live scroll position written to `scroll`,
/// and the overflow fade its host answers from a `StripRun`. A host
/// that takes keyboard focus follows through `StripRun.followAnchor`.
struct SidewaysStrip<Content: View>: View {
    @Binding var scroll: StripScroll
    let fades: ShelfOverflow.Fades
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal) {
            content.onGeometryChange(for: CGFloat.self) {
                -$0.frame(in: .named(Self.space)).minX
            } action: {
                scroll.offset = $0
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            scroll.viewport = $0
        }
        .mask(StripFade(fades: fades))
    }

    nonisolated private static var space: String { "sidewaysStrip" }
}
