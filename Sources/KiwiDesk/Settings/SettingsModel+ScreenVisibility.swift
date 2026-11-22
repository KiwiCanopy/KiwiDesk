import KiwiDeskCore
import SwiftUI

/// Which bar a Per screen row's Show menu writes (#3517 ruling
/// 30): the Space Bar's one visibility, or the App Bar's, which
/// each layout holds for itself.
enum ScreenShowBar {
    case space
    case app
}

/// The Show menu in a bar's Per screen rows (#3517 ruling 30): an
/// area's own visibility, keyed by its `ScreenAreaKey` — an unsplit
/// screen by its fingerprint.
extension SettingsModel {
    /// What `key` shows for `bar`: its own value, else the Space
    /// Bar's own; nil for an App Bar area with no value of its own,
    /// which follows each layout.
    func screenShow(_ bar: ScreenShowBar, on key: String) -> ShelfVisibility? {
        let settings = config.settings
        switch bar {
        case .space:
            return settings.spaceBarStyle.visibilityOverride[key]
                ?? settings.spaceBarStyle.visibility
        case .app:
            return settings.appBarStyle.visibilityOverride[key]
        }
    }

    /// The menu's binding: the Space Bar's own value stores nothing
    /// for the area; the App Bar's nil, Per layout, clears it.
    func screenShowBinding(
        _ bar: ScreenShowBar,
        on key: String
    ) -> Binding<ShelfVisibility?> {
        Binding(
            get: { self.screenShow(bar, on: key) },
            set: { value in
                var next = self.config.settings
                switch bar {
                case .space:
                    guard let value else { return }
                    next.spaceBarStyle.setVisibility(value, on: key)
                case .app:
                    next.appBarStyle.visibilityOverride[key] = value
                }
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// A bar's own Show row — the Space Bar's, or a layout's App
    /// Bar's at `path` — whose pick clears that bar's per-screen
    /// and per-area values (#3517 ruling 32), as a bar's edge pick
    /// clears its screens' edges.
    func barShowBinding(
        _ path: WritableKeyPath<TilingSettings, ShelfVisibility>,
        clearing bar: ScreenShowBar
    ) -> Binding<ShelfVisibility> {
        Binding(
            get: { self.config.settings[keyPath: path] },
            set: { value in
                var next = self.config.settings
                next[keyPath: path] = value
                switch bar {
                case .space: next.spaceBarStyle.visibilityOverride = [:]
                case .app: next.appBarStyle.visibilityOverride = [:]
                }
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// Whether `bar` gives some screen or area a visibility of its
    /// own, which holds its Per screen drawer open.
    func hasScreenShows(_ bar: ScreenShowBar) -> Bool {
        switch bar {
        case .space:
            !config.settings.spaceBarStyle.visibilityOverride.isEmpty
        case .app:
            !config.settings.appBarStyle.visibilityOverride.isEmpty
        }
    }

    /// The Show menu's choices for `bar`: the App Bar's Per layout,
    /// which stores nothing, leads its three values.
    static func screenShowOptions(
        _ bar: ScreenShowBar
    ) -> [(ShelfVisibility?, String)] {
        let values = AppBarOptions.visibility.map {
            (Optional($0.0), $0.1)
        }
        guard bar == .app else { return values }
        return [(nil, perLayout)] + values
    }

    /// The App Bar's "no value of its own" choice.
    static var perLayout: String {
        L("kiwishelf.show.screen.app_bar.per_layout", "Per layout")
    }
}
