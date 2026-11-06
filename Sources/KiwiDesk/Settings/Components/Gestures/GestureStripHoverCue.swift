import SwiftUI

/// A strip picture's pointer half (#2537): the click that lands on
/// its entry, and under the pointer the hover edge, the rise and the
/// pointing hand, the one cue that the picture is a link (#3042). The
/// faded picture arrives as a stored value, so a hover redraws this
/// view and never rebuilds the picture (owner ruling 2026-10-18).
struct GestureStripHoverCue<Content: View>: View {
    let onTap: () -> Void
    private let content: Content
    @State private var hovering = false

    init(onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: SettingsTheme.disclosureRadius
        )
        content
            // Over the fade, so an off gesture's edge is as strong.
            .overlay {
                shape
                    .strokeBorder(
                        SettingsTheme.hoverEdge.opacity(hovering ? 1 : 0),
                        lineWidth: SettingsTheme.hoverEdgeStroke
                    )
                    .allowsHitTesting(false)
            }
            .hoverRise(hovering, in: shape)
            .onTapGesture(perform: onTap)
            .onHover { hovering = $0 }
            .pointingHandCursor()
    }
}
