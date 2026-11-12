import SwiftUI

/// A KiwiHub vertical scroll that fades its top or bottom edge only
/// while content lies past it (#3166) — the one cue that a list
/// runs on, on every side (#3249). `FadingColumn` adds the
/// selection's reveal; the Shortcuts sheet, which has none, takes
/// this bare.
struct FadingScroll<Content: View>: View {
    /// The margin above the first item and below the last.
    var inset: CGFloat = 0
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var height: CGFloat = 0
    /// Its own coordinate space: a scroll nests inside the side.
    @State private var space = UUID()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .padding(.vertical, inset)
                .background(measure)
        }
        .coordinateSpace(.named(space))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            height = $0
        }
        .mask(mask)
    }

    /// The fade's depth here: a viewport too short for two fades
    /// and a line between them takes a shallower one.
    private var fade: CGFloat { EdgeFade.depth(viewport: height) }

    private var measure: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { read(geometry) }
                .onChange(of: geometry.frame(in: .named(space))) {
                    read(geometry)
                }
        }
    }

    private func read(_ geometry: GeometryProxy) {
        let frame = geometry.frame(in: .named(space))
        offset = frame.minY
        contentHeight = frame.height
    }

    /// Opaque where nothing is cut; each cut edge fades out.
    private var mask: some View {
        let (top, bottom) = EdgeFade.cuts(
            offset: offset,
            content: contentHeight,
            viewport: height,
            inset: inset
        )
        return VStack(spacing: 0) {
            LinearGradient(
                colors: [top ? .clear : .black, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fade)
            Rectangle()
            LinearGradient(
                colors: [.black, bottom ? .clear : .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fade)
        }
    }
}

/// Which edges of a KiwiHub scroll cut an item (#3166): content
/// off an edge by the list's own margin alone cuts nothing.
enum EdgeFade {
    /// How deep a vertical KiwiHub list's edge fades.
    static let depth: CGFloat = 20

    /// The depth in a `viewport` this tall: never more than a
    /// quarter of it, so half stays clear between the two fades.
    static func depth(viewport: CGFloat) -> CGFloat {
        min(depth, max(viewport, 0) / 4)
    }

    static func cuts(
        offset: CGFloat,
        content: CGFloat,
        viewport: CGFloat,
        inset: CGFloat
    ) -> (start: Bool, end: Bool) {
        (offset < -inset - 0.5, offset + content > viewport + inset + 0.5)
    }
}
