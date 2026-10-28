import SwiftUI

/// A scroll view's cue that it holds more than it shows: the
/// scroller flashes on open and the content's bottom edge fades
/// while more is below (#1542 ruling, #2705). The content itself
/// fades, since a painted band would show on glass (#1849).
/// Both cues are macOS 15 APIs; macOS 14 keeps the plain scroller.
struct MoreBelowFade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moreBelow = false

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .scrollIndicatorsFlash(onAppear: true)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height
                        - geometry.contentOffset.y
                        - geometry.containerSize.height > 4
                } action: { _, below in
                    moreBelow = below
                }
                .mask { fade }
        } else {
            content
        }
    }

    private var fade: some View {
        // A mask reads alpha alone; `.primary` is any opaque ink.
        VStack(spacing: 0) {
            Rectangle().fill(.primary)
            LinearGradient(
                colors: [.primary, .primary.opacity(moreBelow ? 0 : 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 34)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: moreBelow
        )
    }
}

extension View {
    /// Applies `MoreBelowFade` to a scroll view.
    func moreBelowFade() -> some View {
        modifier(MoreBelowFade())
    }
}
