import KiwiDeskCore

/// The Layouts scope of the key panel (#2229): its keys, its
/// query and the scope switch that reaches it.
extension JumpModel {
    /// Re-reads the picker's Space after Keep, keeping the
    /// selection and the query.
    func reloadLayouts() {
        guard let old = layouts,
            var fresh = loadLayouts(old.state.space)
        else { return }
        let selected = old.selected
        fresh.setQuery(old.query)
        if let selected, fresh.selected != selected {
            fresh.select(selected)
        }
        layouts = fresh
    }

    func setLayoutQuery(_ query: String) {
        guard layouts != nil else { return }
        layouts?.setQuery(query)
        onAnnounce(layoutsSpoken)
    }

    func handleLayouts(_ key: JumpKey) {
        guard let layouts else { return }
        switch key {
        case .side(let delta):
            let before = layouts.selection
            self.layouts?.step(delta)
            if self.layouts?.selection != before {
                onAnnounce(layoutsSpoken)
            }
        case .pick:
            if let mode = layouts.selected { onApply(mode) }
        case .quick(let index, _):
            if let mode = layouts.quick(index) { onApply(mode) }
        case .keep:
            if layouts.state.keepArmed, layouts.state.profile != nil {
                onKeep()
            }
        case .layoutDefaults:
            onLayoutDefaults(layouts.selected ?? layouts.state.live)
        case .escape:
            if layouts.query.isEmpty {
                onClose()
            } else {
                setLayoutQuery("")
            }
        case .step, .page, .toggleScope, .swallow:
            break
        }
    }

    /// The field's stand-in for the typing in Layouts: the
    /// selected layout, or nothing where the query matches none.
    var layoutField: JumpGhost.Field? {
        guard let layouts, let mode = layouts.selected else { return nil }
        return JumpGhost.layoutField(
            name: mode.displayName,
            query: layouts.query
        )
    }

    /// What VoiceOver hears as the Layouts selection moves.
    var layoutsSpoken: String {
        guard let layouts else { return "" }
        guard let mode = layouts.selected else {
            return LayoutPickText.noMatch(layouts.query)
        }
        return LayoutPickText.spoken(mode, current: mode == layouts.state.live)
    }
}
