import AppKit

/// A Space item's glyph and badge views (#1942): a render reuses
/// the views the last one placed, slot by slot, and mints only
/// what the new `apps` adds — a switch that changes no app list
/// mints nothing. A walk re-mints, since its glyphs carry motion
/// of their own (#1528 item 21).
extension SpaceBarItemView {
    func syncAppViews(startsWalk: Bool, keepsLeaving: Bool) {
        // A walk keeps the glyphs it carries off, so they fade
        // under their disc rather than vanish (#1528 item 21).
        let leaving =
            startsWalk ? Self.leaving(appViews, walk: pendingWalk) : []
        if !keepsLeaving {
            leavingViews.forEach { $0.removeFromSuperview() }
            leavingViews = leaving
        }
        if startsWalk {
            appViews.filter { view in
                !leaving.contains { $0 === view }
            }.forEach { $0.removeFromSuperview() }
            appViews = []
            badgeViews.forEach { $0.removeFromSuperview() }
            badgeViews = []
            stickyBadgeViews.forEach { $0?.removeFromSuperview() }
            stickyBadgeViews = []
            floatingBadgeViews.forEach { $0?.removeFromSuperview() }
            floatingBadgeViews = []
        }
        syncGlyphs()
        syncCountBadges()
        stickyBadgeViews = syncStateBadges(stickyBadgeViews) { app in
            app.sticky
                ? StickyStyle.symbolName(for: app.stickyScope)
                    ?? StickyStyle.symbolName
                : nil
        }
        floatingBadgeViews = syncStateBadges(floatingBadgeViews) {
            $0.floating ? Self.floatingSymbol : nil
        }
    }

    private func syncGlyphs() {
        let old = appViews
        appViews = apps.enumerated().map { index, app in
            let reused = old.indices.contains(index) ? old[index] : nil
            if app.glyph != nil {
                if let field = reused as? NSTextField { return field }
                reused?.removeFromSuperview()
                let tf = NSTextField(labelWithString: "")
                tf.alignment = .center
                tf.setAccessibilityElement(false)
                // Beneath the discs, which a walking glyph passes
                // under.
                addMinted(tf, below: overflowBadge)
                return tf
            }
            if let image = reused as? NSImageView {
                if image.image !== app.icon { image.image = app.icon }
                return image
            }
            reused?.removeFromSuperview()
            let iv = NSImageView()
            iv.image = app.icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.setAccessibilityElement(false)
            addMinted(iv, below: overflowBadge)
            return iv
        }
        old.dropFirst(apps.count).forEach { $0.removeFromSuperview() }
    }

    private func syncCountBadges() {
        badgeViews.dropFirst(apps.count).forEach {
            $0.removeFromSuperview()
        }
        badgeViews = apps.indices.map { index in
            if badgeViews.indices.contains(index) {
                return badgeViews[index]
            }
            let badge = Self.makeBadge()
            addMinted(badge)
            return badge
        }
    }

    /// The state marks for `apps`: a mark only on an app `symbol`
    /// names one for, reused where one stands.
    private func syncStateBadges(
        _ old: [StateBadgeView?],
        symbol: (App) -> String?
    ) -> [StateBadgeView?] {
        old.dropFirst(apps.count).forEach { $0?.removeFromSuperview() }
        return apps.enumerated().map { index, app in
            let reused = old.indices.contains(index) ? old[index] : nil
            guard let name = symbol(app) else {
                reused?.removeFromSuperview()
                return nil
            }
            if let reused {
                reused.symbolName = name
                return reused
            }
            let badge = StateBadgeView(symbolName: name)
            addMinted(badge)
            return badge
        }
    }

    private func addMinted(_ view: NSView, below sibling: NSView? = nil) {
        WorkMeter.shared.add(\.barViewsMinted)
        if let sibling {
            addSubview(view, positioned: .below, relativeTo: sibling)
        } else {
            addSubview(view)
        }
    }
}
