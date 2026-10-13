import AppKit
import KiwiDeskCore

/// The key panel's Layouts scope (#2229): which Space it reads,
/// and what its tiles and buttons do.
extension JumpPanelController {
    func wireLayouts(_ model: JumpModel) {
        model.loadLayouts = { [weak self] space in
            guard let self,
                let id = space ?? self.pickerSpace,
                let state = self.core.layoutPickerState(for: id)
            else { return nil }
            return LayoutPickList(state: state, names: Self.layoutNames)
        }
        model.onApply = { [weak self, weak model] mode in
            guard let self, let space = model?.layouts?.state.space
            else { return }
            self.apply(mode, to: space)
        }
        model.onKeep = { [weak self, weak model] in
            self?.core.barMenuHooks.keepLayout()
            model?.reloadLayouts()
        }
        // No distrust: the next own focus report is Settings coming
        // forward, which the grace would eat (#952).
        model.onLayoutDefaults = { [weak self] mode in
            guard let self, self.dismiss(distrusting: false) else { return }
            self.core.barMenuHooks.openSettings(.layoutDefaults(mode))
        }
    }

    /// Closes on a pick, then sets the layout — once: a click
    /// during the exit fade applies nothing.
    private func apply(_ mode: LayoutMode, to space: SpaceID) {
        guard dismiss(distrusting: true) else { return }
        core.applyLayout(mode, to: space)
    }

    @MainActor static var layoutNames: [LayoutMode: String] {
        Dictionary(
            uniqueKeysWithValues: LayoutMode.allCases.map {
                ($0, $0.displayName)
            }
        )
    }
}
