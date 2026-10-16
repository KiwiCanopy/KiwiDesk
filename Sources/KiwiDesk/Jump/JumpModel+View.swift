import KiwiDeskCore

/// KiwiHub's View side (#2229, #2309): its keys, its query and
/// the scope switch that reaches it.
extension JumpModel {
    /// Re-reads the side after Keep, keeping the selection and the
    /// query.
    func reloadView() {
        guard let old = view else { return }
        var fresh = loadView()
        fresh.setQuery(old.query)
        if let selected = old.selected, fresh.selected != selected {
            fresh.select(selected.pick)
        }
        view = fresh
    }

    func setViewQuery(_ query: String) {
        guard view != nil else { return }
        view?.setQuery(query)
        onAnnounce(viewSpoken)
    }

    func handleView(_ key: JumpKey) {
        guard let view else { return }
        switch key {
        case .side(let delta):
            moveViewSelection { $0.step(delta) }
        case .step(let delta):
            moveViewSelection { $0.moveLine(delta) }
        case .pick(moveHere: false):
            if let item = view.selected { applyView(item) }
        // ⇧⌘+digit does nothing on this side (#2309 ruling 4).
        case .quick(let index, moveHere: false):
            if let item = view.quick(index) { applyView(item) }
        case .keep:
            if let layout = view.layout, layout.keepArmed,
                layout.profile != nil
            {
                onKeep()
            }
        case .settings:
            onViewSettings(view.selection?.line ?? .layout, view.selected)
        case .escape:
            if view.query.isEmpty {
                onClose()
            } else {
                setViewQuery("")
            }
        case .pick, .quick, .page, .stepScope, .swallow:
            break
        }
    }

    /// The one door every View pick takes — ↩, a ⌘ digit, a click
    /// — so what an item does is decided once: the KiwiVision item
    /// already on turns KiwiVision off (#2103 ruling 56).
    func applyView(_ item: ViewPickList.Item) {
        guard item.isApplicable else { return }
        onApplyView(ViewPickList.action(of: item))
    }

    private func moveViewSelection(_ move: (inout ViewPickList) -> Void) {
        guard var list = view else { return }
        let before = list.selection
        move(&list)
        view = list
        if list.selection != before { onAnnounce(viewSpoken) }
    }

    /// How many items the ⌘ numbers reach on the selected line.
    var viewQuickCount: Int {
        guard let view, let line = view.selection?.line else { return 0 }
        return min(view.digitOrder(line).count, 9)
    }

    /// What VoiceOver hears as the View selection moves.
    var viewSpoken: String {
        guard let view else { return "" }
        guard let line = view.selection?.line, let item = view.selected
        else {
            return ViewPickText.noMatch(view.query)
        }
        return ViewPickText.spoken(
            item,
            on: line,
            visionOff: view.visionIsOff
        )
    }
}
