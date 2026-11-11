import SwiftUI

/// A KiwiHub list that scrolls down: it fades its top or bottom
/// edge only while content lies beyond it, and scrolls the
/// selected item clear of the fade (#3164). The Desktops side's
/// screen rows and each Desktop's Space lines take it.
struct FadingColumn<Selected: Hashable, Content: View>: View {
    /// The selected item's id, where it is in this list; items
    /// mark themselves with `fadingTarget(_:)`.
    let selected: Selected?
    /// The margin above the first item and below the last.
    var inset: CGFloat = 0
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var height: CGFloat = 0
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    static var fade: CGFloat { EdgeFade.depth }
    private static var space: String { "fadingColumn" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(.vertical, inset)
                    .background(measure)
            }
            .coordinateSpace(name: Self.space)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                height = $0
            }
            .mask(mask)
            .onAppear { reveal(proxy, animated: false) }
            .onChange(of: selected) { reveal(proxy, animated: true) }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let selected else { return }
        withAnimation(
            animated && !reduceMotion ? .easeOut(duration: 0.15) : nil
        ) {
            proxy.scrollTo(selected)
        }
    }

    private var measure: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { read(geometry) }
                .onChange(of: geometry.frame(in: .named(Self.space))) {
                    read(geometry)
                }
        }
    }

    private func read(_ geometry: GeometryProxy) {
        let frame = geometry.frame(in: .named(Self.space))
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
            .frame(height: Self.fade)
            Rectangle()
            LinearGradient(
                colors: [.black, bottom ? .clear : .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.fade)
        }
    }
}

/// Which edges of a KiwiHub scroll cut an item (#3166): content
/// off an edge by the list's own margin alone cuts nothing.
enum EdgeFade {
    /// How deep a vertical KiwiHub list's edge fades.
    static let depth: CGFloat = 20

    static func cuts(
        offset: CGFloat,
        content: CGFloat,
        viewport: CGFloat,
        inset: CGFloat
    ) -> (start: Bool, end: Bool) {
        (offset < -inset - 0.5, offset + content > viewport + inset + 0.5)
    }
}

extension View {
    /// Marks an item a `FadingColumn` scrolls to: a reveal brings
    /// it in with a fade's depth to spare on each side, so the
    /// selected item never sits under the fade.
    func fadingTarget<ID: Hashable>(_ id: ID) -> some View {
        background {
            Color.clear
                .padding(.vertical, -EdgeFade.depth)
                .id(id)
        }
    }
}
