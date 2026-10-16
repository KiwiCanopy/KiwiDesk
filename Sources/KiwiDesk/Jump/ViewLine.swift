import KiwiDeskCore
import SwiftUI

/// One line of the View side (#2309 ruling 3): it never wraps; a
/// line longer than the panel scrolls sideways, keeps the
/// selection in view and fades at each edge it cuts.
struct ViewLine<Content: View>: View {
    /// The selected item's id, where it is on this line.
    let selected: ViewPickList.Pick?
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
                    .padding(.horizontal, KeyPanelStyle.selectionInset)
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

    /// Opaque where nothing is cut; each cut edge fades out.
    private var mask: some View {
        let leading = offset < -0.5
        let trailing = offset + contentWidth > width + 0.5
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
