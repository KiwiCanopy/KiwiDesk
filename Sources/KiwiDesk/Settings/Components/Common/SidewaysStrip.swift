import KiwiDeskCore
import SwiftUI

/// The one sideways scroller of a Settings strip (#2987): the
/// platform's scroller, the overflow fade answered by `run`, and a
/// scroll that brings `followed` clear of that fade. It owns the
/// scroll position, so a scroll tick never re-evaluates its host.
struct SidewaysStrip<ID: Hashable, Content: View>: View {
    private let run: StripRun
    private let followed: StripFollow<ID>?
    private let content: Content
    @State private var scroll = StripScroll()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        run: StripRun,
        followed: StripFollow<ID>?,
        @ViewBuilder content: () -> Content
    ) {
        self.run = run
        self.followed = followed
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                content
                    .modifier(
                        StripScrollerRoom(
                            contentWidth: run.total,
                            viewport: scroll.viewport,
                            floor: SettingsTheme.hoverRiseShadowRoom
                        )
                    )
                    // Inside the clip: a risen tile and its shadow, and
                    // past the ends the run's room, given back outside
                    // so the row still lines up.
                    .padding(.top, SettingsTheme.hoverRiseTopRoom)
                    .padding(.horizontal, run.endRoom)
                    .onGeometryChange(for: CGFloat.self) {
                        -$0.frame(in: .named(stripSpace)).minX
                    } action: {
                        scroll.offset = $0
                    }
            }
            .coordinateSpace(.named(stripSpace))
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                scroll.viewport = $0
            }
            .mask(StripFade(fades: run.fades(scroll)))
            .onChange(of: followed) { _, item in
                follow(item, with: proxy)
            }
        }
        .padding(.horizontal, -run.endRoom)
    }

    private func follow(
        _ item: StripFollow<ID>?,
        with proxy: ScrollViewProxy
    ) {
        guard let item,
            let anchor = run.followAnchor(index: item.index, scroll: scroll)
        else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(item.id, anchor: anchor)
        }
    }
}

extension SidewaysStrip where ID == Never {
    /// A strip no keyboard focus reaches.
    init(run: StripRun, @ViewBuilder content: () -> Content) {
        self.init(run: run, followed: nil, content: content)
    }
}

private let stripSpace = "sidewaysStrip"
