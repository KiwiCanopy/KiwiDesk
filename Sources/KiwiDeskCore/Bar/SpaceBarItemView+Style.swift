import AppKit

/// State-dependent styling for one Space item (#293): the box,
/// the two-accent identifier/glyph tints, the count and
/// overflow badges, and the active indicator. Split from
/// `SpaceBarItemView.swift` for the file ceiling.
extension SpaceBarItemView {

    func restyle() {
        layer?.masksToBounds = true
        layer?.cornerRadius =
            style.tabBackground.rendered == .boxed ? cornerRadius : 0
        layer?.backgroundColor = boxColor.cgColor
        styleIdentifier()
        styleApps()
        styleBadges()
        styleDivider()
        styleAccent()
    }

    /// The identifier↔glyphs rule (QA 2026-07-19): structural
    /// chrome, so it stays on the muted `textColor` tier
    /// regardless of state — a third state-driven color would
    /// compete with the two accents rather than separate.
    private func styleDivider() {
        identifierDivider.isHidden = apps.isEmpty
        identifierDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.textColor)
            .cgColor
    }

    /// Untinted content (emoji identifiers, native app images)
    /// takes no state color, so it carried no inactive cue at
    /// all (QA 2026-07-19). Alpha is the channel that respects
    /// "never tint": half strength when inactive, full on the
    /// active space and under the pointer — legible enough to
    /// identify, clearly secondary.
    private var untintedAlpha: CGFloat {
        isActive || isHovered || isDragHovered
            ? 1 : BarAccent.untintedAlpha
    }

    /// Count and overflow badges follow the space state (#293
    /// verdict 5, amended): configured badge colors on the
    /// active space, muted (derived from `textColor`) on
    /// inactive ones — a saturated badge on a muted space would
    /// fight the two-accent hierarchy.
    private func styleBadges() {
        let background =
            isActive
            ? NSColor(kiwiHex: style.groupBadgeColor)
            : NSColor(kiwiHex: style.textColor)
                .withAlphaComponent(SpaceBarStyle.mutedBadgeAlpha)
        let text =
            isActive
            ? NSColor(kiwiHex: style.groupBadgeTextColor)
            : NSColor(kiwiHex: style.textColor)
        for (index, app) in apps.enumerated() {
            guard index < badgeViews.count else { break }
            let badge = badgeViews[index]
            badge.isHidden = app.count < 2
            badge.stringValue = "\(app.count)"
            badge.layer?.backgroundColor = background.cgColor
            badge.textColor = text
        }
        overflowBadge.isHidden = overflow < 1
        overflowBadge.stringValue = "+\(overflow)"
        overflowBadge.layer?.backgroundColor =
            background.cgColor
        overflowBadge.textColor = text
    }

    var cornerRadius: CGFloat {
        style.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
    }

    private var boxColor: NSColor {
        // Active wins over hover (matching `stateColor` and the
        // mouseEntered guard): a click that activates the item
        // under the pointer must not leave it hover-tinted.
        if isActive, style.tabBackground.rendered == .boxed {
            return NSColor(kiwiHex: style.activeBoxColor)
        }
        if isActive { return .clear }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverColor)
        }
        guard style.tabBackground.rendered == .boxed else {
            return .clear
        }
        return NSColor(kiwiHex: style.boxColor)
    }

    /// The state tier a tinted element takes: active space
    /// accent, hover text, or the inactive tier.
    private var stateColor: NSColor {
        if isActive {
            return NSColor(kiwiHex: style.activeTextColor)
        }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverTextColor)
        }
        return NSColor(kiwiHex: style.textColor)
    }

    private func styleIdentifier() {
        switch spaceGlyph {
        case .symbol(let name):
            identifierLabel.isHidden = true
            identifierImage.isHidden = false
            identifierImage.image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            )
            identifierImage.symbolConfiguration =
                NSImage.SymbolConfiguration(
                    pointSize: identifierFont,
                    weight: .regular
                )
            identifierImage.contentTintColor = stateColor
        case .text(let text, let tinted):
            identifierImage.isHidden = true
            identifierLabel.isHidden = false
            identifierLabel.stringValue = text
            identifierLabel.textColor =
                tinted ? stateColor : .labelColor
            identifierLabel.alphaValue =
                tinted ? 1 : untintedAlpha
        }
    }

    private func styleApps() {
        for (index, app) in apps.enumerated() {
            guard index < appViews.count else { break }
            if let glyphField = appViews[index] as? NSTextField {
                glyphField.stringValue = app.glyph ?? ""
                glyphField.font =
                    AppFont.font(size: glyphSize)
                    ?? .systemFont(ofSize: glyphSize)
                glyphField.textColor =
                    app.focused && isActive
                    ? NSColor(kiwiHex: style.focusedItemColor)
                    : stateColor
            } else {
                appViews[index].alphaValue = untintedAlpha
            }
        }
    }

    private func styleAccent() {
        accent.isHidden = !isActive
        guard isActive else { return }
        let highlight = NSColor(kiwiHex: style.highlightColor)
        switch style.activeIndicator {
        case .ring:
            accent.layer?.backgroundColor = nil
            accent.layer?.borderColor = highlight.cgColor
            accent.layer?.borderWidth = 2
            // Plain/material: the App Bar's capsule ring —
            // roundness-independent, and its fully-curved ends
            // tuck inside the shared plate's corners where the
            // old square accent poked past them (QA 2026-07-19).
            // Bounds-derived (not `accent.frame`): restyle runs
            // before layout places the accent, so the frame may
            // be stale here.
            accent.layer?.cornerRadius =
                style.tabBackground.rendered == .boxed
                ? cornerRadius
                : max(
                    (min(bounds.width, bounds.height)
                        - BarAccent.capsuleInset * 2) / 2,
                    0
                )
        case .edgeMark:
            accent.layer?.borderWidth = 0
            accent.layer?.cornerRadius = 0
            accent.layer?.backgroundColor = highlight.cgColor
        case .gap:
            // No shape marker: `gap` hides the App Bar's active
            // item, which cannot apply to a space identifier —
            // colors alone carry the state.
            accent.isHidden = true
        }
    }

    /// Both sizes read `SpaceBarStyle`'s one ladder — the
    /// front-app glyph reads the same one, so every glyph
    /// renders an app at one size.
    var identifierFont: CGFloat {
        style.identifierFontSize(
            forDepth: horizontal ? bounds.height : bounds.width
        )
    }

    var glyphSize: CGFloat {
        style.glyphFontSize(
            forDepth: horizontal ? bounds.height : bounds.width
        )
    }
}
