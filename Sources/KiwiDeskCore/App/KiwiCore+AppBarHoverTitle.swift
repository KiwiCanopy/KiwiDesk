import Foundation

/// An App Bar item's hover title (#1514's ruling): shown only
/// where the item hides text — its title cut at `title_cap` or by
/// its width, or no label drawn (a vertical bar is icon-only) —
/// as the app, then the full window title.
extension KiwiCore {
    func wireAppBarHoverTitle() {
        appBars.hoverTitle.read = { [weak self] id, count, drawn in
            self?.appBarHoverTitle(window: id, count: count, drawn: drawn)
        }
    }

    /// `drawn` is the text the item showed in full, or nil. A
    /// group's text is its app name, so it owes a tooltip only
    /// where that name is not drawn.
    func appBarHoverTitle(
        window id: WindowID,
        count: Int,
        drawn: String?
    ) -> String? {
        guard let window = state.windows[id] else { return nil }
        let title =
            count == 1 && !window.title.isEmpty ? window.title : nil
        let whole = title ?? window.appName
        guard drawn != whole else { return nil }
        return ([window.appName] + [title].compactMap { $0 })
            .joined(separator: "\n")
    }
}
