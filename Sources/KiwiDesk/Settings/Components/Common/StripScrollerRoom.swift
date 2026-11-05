import AppKit
import SwiftUI

/// The one clearance under a sideways scroller's content, keeping an
/// overlay scroller off it (#2901). Applied inside the `ScrollView`,
/// and following the system's scroller style as it changes.
struct StripScrollerRoom: ViewModifier {
    let contentWidth: CGFloat
    let viewport: CGFloat
    @State private var style = NSScroller.preferredScrollerStyle

    /// An overlay scroller's height over the content's bottom edge.
    /// Measured on macOS 27 in a SwiftUI `ScrollView`, 2026-11-05.
    nonisolated static let overlayHeight: CGFloat = 17

    func body(content: Content) -> some View {
        content
            .padding(
                .bottom,
                Self.room(
                    contentWidth: contentWidth,
                    viewport: viewport,
                    style: style
                )
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSScroller.preferredScrollerStyleDidChangeNotification
                )
            ) { _ in
                style = NSScroller.preferredScrollerStyle
            }
    }

    /// No room where no scroller draws, or before the viewport is
    /// measured. A legacy scroller gets none either: SwiftUI already
    /// grows the scroll view by its height.
    nonisolated static func room(
        contentWidth: CGFloat,
        viewport: CGFloat,
        style: NSScroller.Style
    ) -> CGFloat {
        guard style == .overlay, viewport > 0, contentWidth > viewport
        else { return 0 }
        return overlayHeight
    }
}
