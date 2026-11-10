import KiwiDeskCore

/// Where a reveal of an anchor goes before the anchor itself on a
/// lazily built page (#3060).
enum RevealLanding: Equatable {
    /// Scroll to this part's id first, so the stack builds it.
    case part(String)
    /// No part is known to hold the anchor: build the whole page.
    case wholePage
}

extension SettingsModel {
    /// How a reveal of `anchor` reaches it; nil where the anchor is
    /// already in the stack. A lazily built page joins the switch.
    func revealLanding(for anchor: String) -> RevealLanding? {
        switch destination {
        case .shortcuts:
            return ShortcutsPagePart.landing(for: anchor, in: self)
        default: return nil
        }
    }

    /// Shows the Shortcuts page's part drawing `anchor` (#3184);
    /// an anchor no part is known to hold leaves the part shown.
    func showShortcutsSegment(holding anchor: String) {
        let owner = ShortcutsPagePart.owner(
            of: anchor,
            expander: .ofDraft(self, layer: nav.shortcutsLayerSelection),
            bindings: shortcutsLayerBindings
        )
        guard let owner else { return }
        nav.shortcutsSegment = owner.segment(
            from: nav.shortcutsSegmentSelection
        )
    }

    /// The selected Shortcuts layer's rows, falling back to the first
    /// layer as the page's binding does while a selection is stale.
    var shortcutsLayerBindings: [KeyBinding] {
        let layer = nav.shortcutsLayerSelection
        let index = config.layers.firstIndex { $0.name == layer } ?? 0
        return config.layers.indices.contains(index)
            ? config.layers[index].bindings : []
    }
}
