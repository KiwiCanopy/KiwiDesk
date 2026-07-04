import AppKit

/// Keeps the monocle indicator bar in sync with the active
/// space. Driven from `retile()`, which already fires on
/// every structural, focus, mode, and settings change.
extension KiwiCore {
    func updateMonocleBar() {
        let params = tiler.settings.monocle
        guard let space = activeSpace,
            space.mode == .monocle,
            params.bar.enabled,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else {
            monocleBar.hide()
            return
        }
        let tiled = space.windows.filter { id in
            state.windows[id]?.isFloating == false
        }
        let context = tiler.settings.context(
            bounds: GeometryUtils.axVisibleFrame(of: screen),
            space: space
        )
        guard !tiled.isEmpty,
            let strip = params.barFrame(in: context.usable)
        else {
            monocleBar.hide()
            return
        }
        monocleBar.show(
            items: tiled.map(barItem),
            activeIndex: space.focused.flatMap {
                tiled.firstIndex(of: $0)
            },
            strip: strip,
            params: params
        )
    }

    private func barItem(
        for id: WindowID
    ) -> IndicatorBarOverlay.Item {
        let window = state.windows[id]
        return IndicatorBarOverlay.Item(
            id: id,
            name: window?.appName ?? "?",
            icon: window.flatMap {
                NSRunningApplication(
                    processIdentifier: $0.pid
                )?.icon
            }
        )
    }
}
