import Foundation

/// An App Bar item's hover title (#1514's ruling): the app, then
/// the full window title, asked only where the item hides text —
/// the view decides that from Core's cut verdict and what it drew.
extension KiwiCore {
    func wireAppBarHoverTitle() {
        appBars.itemActions.tooltip = { [weak self] id, count in
            self?.appBarHoverTitle(window: id, count: count)
        }
    }

    /// A group's text is its app name, so it lists no title.
    func appBarHoverTitle(window id: WindowID, count: Int) -> String? {
        guard let window = state.windows[id] else { return nil }
        return Self.hoverTitle(
            app: window.appName,
            titles: [barItemTitle(count: count, window: window)]
                .compactMap { $0 }
        )
    }

    /// The bars' hover-title shape: the app on the first line,
    /// then one line per window title (#1514).
    static func hoverTitle(app: String, titles: [String]) -> String {
        ([app] + titles).joined(separator: "\n")
    }
}
