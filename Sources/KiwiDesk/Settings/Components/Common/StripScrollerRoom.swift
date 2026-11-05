import AppKit
import SwiftUI

/// The one clearance under a sideways scroller's content, keeping an
/// overlay scroller off it (#2901). Applied inside the `ScrollView`,
/// and following the system's scroller style as it changes.
struct StripScrollerRoom: ViewModifier {
    let overflows: Bool
    @State private var style = NSScroller.preferredScrollerStyle

    /// An overlay scroller's height over the content's bottom edge.
    /// Measured on macOS 27 in a SwiftUI `ScrollView`, 2026-11-05.
    nonisolated static let overlayHeight: CGFloat = 17

    func body(content: Content) -> some View {
        content
            .padding(
                .bottom,
                Self.room(overflows: overflows, style: style)
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSScroller.preferredScrollerStyleDidChangeNotification
                )
            ) { _ in
                style = NSScroller.preferredScrollerStyle
            }
    }

    /// No room where no scroller draws. A legacy scroller gets none
    /// either: SwiftUI already grows the scroll view by its height.
    nonisolated static func room(
        overflows: Bool,
        style: NSScroller.Style
    ) -> CGFloat {
        overflows && style == .overlay ? overlayHeight : 0
    }
}
