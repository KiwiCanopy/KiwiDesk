import AppKit

/// State-dependent styling for one Space item (#293): the box,
/// the two-accent identifier/glyph tints, the count and
/// overflow badges, and the active indicator. Split from
/// `SpaceBarItemView.swift` for the file ceiling.
extension SpaceBarItemView {

    func restyle() {
        // The item does NOT clip (corner badges must stay whole);
        // the box fill still rounds via cornerRadius, and the active
        // mark clips through `accentClip` to the same corner.
        layer?.masksToBounds = false
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = fillColor.cgColor
        accentClip.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = cornerRadius
        accentClip.layer?.maskedCorners = maskedCorners
        styleIdentifier()
        styleApps()
        styleBadges()
        styleDivider()
        styleAccent()
    }

    /// The identifier↔glyphs rule (QA 2026-07-19): structural
    /// chrome, so it stays on the muted `itemColor` tier
    /// regardless of state — a third state-driven color would
    /// compete with the two accents rather than separate.
    private func styleDivider() {
        identifierDivider.isHidden = apps.isEmpty
        identifierDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor)
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
            ? 1 : style.dimFactor
    }

    /// Count and overflow badges follow the space state (#293
    /// verdict 5, amended): configured badge colors on the
    /// active space, muted (derived from `itemColor`) on
    /// inactive ones — a saturated badge on a muted space would
    /// fight the two-accent hierarchy.
    private func styleBadges() {
        for (index, app) in apps.enumerated() {
            guard index < badgeViews.count else { break }
            let badge = badgeViews[index]
            badge.isHidden = app.count < 2
            badge.stringValue = "\(app.count)"
            applyBadge(badge, appFocused: app.focused)
        }
        overflowBadge.isHidden = overflow < 1
        overflowBadge.stringValue = "+\(overflow)"
        applyBadge(overflowBadge, appFocused: focusInOverflow)
        styleStateBadges()
    }

    /// The sticky / floating corner badges (#414): shown per
    /// slot from the group aggregate ("at least one"), gated by
    /// the Lua-only `space_bar.sticky_badge`, tinted through
    /// the same ladder as the glyph they mark.
    private func styleStateBadges() {
        for (index, app) in apps.enumerated() {
            guard index < stickyBadgeViews.count,
                index < floatingBadgeViews.count
            else { break }
            let tint =
                app.focused && isActive
                ? NSColor(kiwiHex: style.focusedItemColor)
                : stateColor
            let alpha = untintedAppAlpha(focused: app.focused)
            let sticky = stickyBadgeViews[index]
            sticky.isHidden =
                !(style.stickyBadge && app.sticky)
            sticky.contentTintColor = tint
            sticky.alphaValue = alpha
            let floating = floatingBadgeViews[index]
            floating.isHidden =
                !(style.stickyBadge && app.floating)
            floating.contentTintColor = tint
            floating.alphaValue = alpha
        }
    }

    /// A count / overflow badge follows the same 3-tier ladder as the
    /// glyphs (owner 2026-07-20): the whole badge (fill AND text)
    /// dims via `alphaValue` to the app's focus tier — full for the
    /// focused app (or on hover), `activeUnfocusedAlpha` for an
    /// unfocused app on the active space, `untintedAlpha` on an
    /// inactive one. Its text takes the focused-window color when
    /// this badge's app holds the focus (walks back #293's muted
    /// itemColor on inactive spaces — one uniform ladder now).
    private func applyBadge(_ badge: NSTextField, appFocused: Bool) {
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: style.groupBadgeColor).cgColor
        badge.textColor =
            appFocused && isActive
            ? NSColor(kiwiHex: style.focusedItemColor)
            : NSColor(kiwiHex: style.groupBadgeTextColor)
        badge.alphaValue = untintedAppAlpha(focused: appFocused)
    }

    var cornerRadius: CGFloat {
        style.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
    }

    /// Which corners `accentClip` rounds. Boxed clips all four (its
    /// own box). Plain clips only the run's outer end — leading on
    /// the first item, trailing on the last (when no front app
    /// trails it) — so the mark cuts on the plate's curve there and
    /// stays square between (owner 2026-07-20).
    private var maskedCorners: CACornerMask {
        let all: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]
        if style.hasBox { return all }
        let leading: CACornerMask =
            horizontal
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let trailing: CACornerMask =
            horizontal
            ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        var corners: CACornerMask = []
        if isFirstInRun { corners.formUnion(leading) }
        if isLastInRun { corners.formUnion(trailing) }
        return corners
    }

    private var fillColor: NSColor {
        // Active wins over hover (matching `stateColor` and the
        // mouseEntered guard): a click that activates the item
        // under the pointer must not leave it hover-tinted.
        if isActive, style.hasBox {
            return NSColor(kiwiHex: style.fillColor)
        }
        if isActive { return .clear }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverFillColor)
        }
        guard style.hasBox else {
            return .clear
        }
        return NSColor(kiwiHex: style.fillColor)
    }

    /// The state tier a tinted element takes: active space
    /// accent, hover text, or the inactive tier.
    private var stateColor: NSColor {
        if isActive {
            return NSColor(kiwiHex: style.activeItemColor)
        }
        if isHovered || isDragHovered {
            return NSColor(kiwiHex: style.hoverItemColor)
        }
        return NSColor(kiwiHex: style.itemColor)
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
                appViews[index].alphaValue =
                    untintedAppAlpha(focused: app.focused)
            }
        }
    }

    /// Three-tier ladder for untinted app glyphs (QA
    /// 2026-07-19): full for the focused app on the active
    /// space, `activeUnfocusedAlpha` for its unfocused
    /// siblings — without it a native icon carried no focus
    /// cue at all — and `untintedAlpha` on inactive spaces.
    /// Hover always lifts to full (explicit intent; one hover
    /// rule, no fourth value).
    private func untintedAppAlpha(
        focused: Bool
    ) -> CGFloat {
        if isHovered || isDragHovered { return 1 }
        guard isActive else {
            return style.dimFactor
        }
        return focused
            ? 1 : style.activeDimFactor
    }

    private func styleAccent() {
        accent.isHidden = !isActive
        guard isActive else { return }
        let highlight = NSColor(kiwiHex: style.highlightColor)
        switch style.activeIndicator {
        case .outline:
            accent.layer?.backgroundColor = nil
            accent.layer?.borderColor = highlight.cgColor
            accent.layer?.borderWidth = 2
            // Plain/material: the ring tracks the shared plate's
            // roundness and stays concentric — inner radius = the
            // plate's resolved corner radius minus the ring inset
            // (owner 2026-07-20). Bounds-derived (not `accent.frame`):
            // restyle runs before layout places the accent, so the
            // frame may be stale here.
            accent.layer?.cornerRadius =
                style.hasBox
                ? cornerRadius
                : max(0, cornerRadius - BarAccent.capsuleInset)
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
