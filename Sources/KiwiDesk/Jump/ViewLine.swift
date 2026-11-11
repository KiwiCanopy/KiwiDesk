import KiwiDeskCore
import SwiftUI

/// One line of the View side (#2309 ruling 3): it never wraps; a
/// line longer than the panel scrolls sideways, keeps the
/// selection in view and fades at each edge with content cut
/// beyond it (#3166). The Desktops side's screen rows take it too
/// (#1229).
struct ViewLine<Selected: Hashable, Content: View>: View {
    /// The selected item's id, where it is on this line.
    let selected: Selected?
    /// The margin before the first item and after the last.
    var inset: CGFloat = KeyPanelStyle.selectionInset
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    static var fade: CGFloat { 24 }
    private static var space: String { "viewLine" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                content
                    .padding(.horizontal, inset)
                    .background(measure)
            }
            .coordinateSpace(name: Self.space)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                width = $0
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
        offset = frame.minX
        contentWidth = frame.width
    }

    /// Which edges cut an item: off an edge by the margin alone,
    /// as a `scrollTo` leaves the end item, cuts nothing (#3166).
    nonisolated static func cuts(
        offset: CGFloat,
        content: CGFloat,
        width: CGFloat,
        inset: CGFloat
    ) -> (leading: Bool, trailing: Bool) {
        let cut = EdgeFade.cuts(
            offset: offset,
            content: content,
            viewport: width,
            inset: inset
        )
        return (cut.start, cut.end)
    }

    /// Opaque where nothing is cut; each cut edge fades out.
    private var mask: some View {
        let (leading, trailing) = Self.cuts(
            offset: offset,
            content: contentWidth,
            width: width,
            inset: inset
        )
        return HStack(spacing: 0) {
            LinearGradient(
                colors: [leading ? .clear : .black, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.fade)
            Rectangle()
            LinearGradient(
                colors: [.black, trailing ? .clear : .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.fade)
        }
    }
}
