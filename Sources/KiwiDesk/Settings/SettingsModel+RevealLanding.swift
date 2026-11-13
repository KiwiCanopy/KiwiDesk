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

    /// The Shortcuts page's part showing `anchor`, from the part
    /// shown (#3184); nil where no part is known to hold it.
    func shortcutsSegment(holding anchor: String) -> ShortcutsSegment? {
        ShortcutsPagePart.placing(
            anchor,
            expander: .ofDraft(self, layer: nav.shortcutsLayerSelection),
            bindings: shortcutsLayerBindings,
            shown: nav.shortcutsSegmentSelection
        )?.segment
    }

    /// Shows the Shortcuts page's part drawing `anchor`; an anchor
    /// no part is known to hold leaves the part shown. A row only
    /// the `default` layer draws selects that layer first (#3260).
    func showShortcutsSegment(holding anchor: String) {
        if ShortcutsGates.drawnOnDefaultLayerAlone(anchor) {
            nav.shortcutsLayer = KeyLayer.defaultName
        }
        if let part = shortcutsSegment(holding: anchor) {
            nav.shortcutsSegment = part
        }
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
