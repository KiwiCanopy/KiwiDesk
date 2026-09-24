import Foundation

extension KiwiCore {
    /// Drops the placeholder Space (`StateCoordinator`) when the
    /// load after its planting neither declared nor named it and
    /// it holds no window (#1526). Rules once per planting.
    ///
    /// Declared is asked of the sources, never of `referenced`:
    /// the display resolve ensures every live Space, the
    /// placeholder included.
    func retirePlaceholderSpace() {
        guard let placeholder = state.placeholderSpace else {
            return
        }
        state.placeholderSpace = nil
        let sidecar =
            isGuiManaged ? guiConfigStore.load()?.spaces ?? [] : []
        guard declaredSources(of: placeholder).isEmpty,
            !sidecar.contains(placeholder),
            fallbackSpace != placeholder,
            spacePins[placeholder] == nil,
            !mainSpaces.contains(placeholder),
            state.workspaces[placeholder]?.windows.isEmpty ?? false,
            let survivor = state.workspaces.order.first(where: {
                $0 != placeholder
            })
        else { return }
        forwardWindows(of: placeholder, to: survivor)
        tiler.settings.removeSpace(placeholder)
        resolveSpaceDisplays()
        emitSpaceChange()
        onLog(
            "boot: dropped undeclared placeholder space "
                + placeholder.raw
        )
    }
}
