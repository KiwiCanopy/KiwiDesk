import KiwiDeskCore

/// What VoiceOver hears on the Desktops side (#1229): counts
/// without plurals, a hidden Desktop's Space "last shown".
extension DesktopsText {
    static func spoken(_ state: DesktopsState) -> String {
        guard let place = state.place, let line = state.line(place),
            let desktop = state.desktop(place)
        else { return "" }
        if let id = state.window, let window = state.overview.window(id) {
            return spoken(window, picked: state.carried.contains(id))
        }
        return spoken(line, on: desktop)
    }

    static func spoken(
        _ window: DesktopOverview.Window,
        picked: Bool
    ) -> String {
        let title = window.title.isEmpty ? window.app : window.title
        return picked
            ? L(
                "desktop_overview.ax.window_picked",
                "%1$@, %2$@, picked",
                window.app,
                title
            )
            : L("desktop_overview.ax.window", "%1$@, %2$@", window.app, title)
    }

    static func spoken(
        _ line: DesktopOverview.SpaceLine,
        on desktop: DesktopOverview.Desktop
    ) -> String {
        let name = line.space.map(space) ?? unfiled
        let card = self.desktop(desktop.label)
        let count = line.windows.count
        guard line.isShown else {
            return L(
                "desktop_overview.ax.place",
                "%1$@, %2$@, windows: %3$d",
                name,
                card,
                count
            )
        }
        return desktop.isShown
            ? L(
                "desktop_overview.ax.place_shown",
                "%1$@, shown, %2$@, windows: %3$d",
                name,
                card,
                count
            )
            : L(
                "desktop_overview.ax.place_last_shown",
                "%1$@, last shown, %2$@, windows: %3$d",
                name,
                card,
                count
            )
    }
}
