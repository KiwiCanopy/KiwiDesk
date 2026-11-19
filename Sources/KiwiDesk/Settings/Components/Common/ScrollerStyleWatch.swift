import AppKit
import Combine

/// The system's scroller style, following it as it changes: the one
/// reader of `NSScroller.preferredScrollerStyle` in Settings and the
/// tour, which a strip's clearance (#2901) and a page's gutter
/// (#3491) both take (`StripScrollerTests` ▸ `clearanceHome`).
@MainActor
final class ScrollerStyleWatch: ObservableObject {
    @Published private(set) var style = NSScroller.preferredScrollerStyle
    private var change: AnyCancellable?

    init() {
        change = NotificationCenter.default
            .publisher(
                for: NSScroller.preferredScrollerStyleDidChangeNotification
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.style = NSScroller.preferredScrollerStyle
            }
    }
}
