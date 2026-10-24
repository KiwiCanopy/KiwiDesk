import AppKit

/// The Fill on Liquid Glass surfaces (`NSGlassEffectView`, #408):
/// a backdrop that is the glass's content, over the material and
/// beneath what it hosts (#2569), and the one place a stored Fill
/// becomes a rendered colour on glass (#1297) — a fade from the
/// shelf's screen edge toward the windows (#1622), or downward on a
/// surface on no edge (#1620, #1621). A reading surface — the bar
/// hover peek — takes no fade at all (`applyUniform`, owner ruling
/// on #1946).
enum GlassTint {
    /// Ceiling on the backdrop's alpha at the fade's ANCHOR edge
    /// — a floor on how much refraction survives, not a legibility
    /// budget. A Fill at or below it renders exactly as picked
    /// there; only what cannot render as glass is bent.
    ///
    /// **Measured and KEPT at 0.65, 2026-09-07, macOS 26.6.2**
    /// (#1297). The retune the issue expected was not needed: the
    /// plate read as a slab because `tintColor` was dimming it
    /// beside this cap, and closing that bypass alone moved the
    /// composite over a bright busy ground from RGB ~(104,106,95)
    /// to ~(122,124,110) — the ground's structure legible through
    /// it, which is the whole of what "reads as glass" meant here.
    ///
    /// Every bundled palette ships its bar fills at `…B3` (0.70),
    /// so on a default install this cap is what the plate actually
    /// renders at — the value a retune moves for most users.
    ///
    /// **What binds the number is the ink, not the blur.** A bar's
    /// item colour is fixed palette hex with no vibrancy path
    /// (`docs/design-decisions.md` ▸ App Bar), so this plate is the
    /// legibility floor. Against `#EAF3EE` over the brightest
    /// patches of a busy ground: 0.65 holds ~3.3:1 and 0.50 falls
    /// to ~2.7:1, for very little further refraction — and this
    /// repo already refused a pairing at ~3.3:1 as too thin at
    /// small sizes (the systemGray badge, #955). So lowering it
    /// spends what the ink has left and buys nearly nothing.
    ///
    /// Retune it over a BLACK and a WHITE wallpaper, both bars,
    /// boxed and plain, and measure the ink against the composite
    /// rather than eyeballing the blur — a flat wallpaper shows no
    /// refraction at any alpha, so a ground with structure in it is
    /// the only instrument that answers. Never subtract from the
    /// alpha a palette happens to ship: that measures the palette.
    ///
    /// Since #1622 this binds the anchor edge only; the clear end
    /// runs at `floorShare` of it, where the #1308 pin, not the
    /// alpha, keeps a dark Fill's glass dark behind the ink.
    static let maxAlpha: CGFloat = 0.65

    /// The fade's far end as a share of the anchor's alpha at the
    /// strongest fade: a hint of the Fill across the whole surface,
    /// never fully clear (owner ruling 2026-09-24, #1622).
    static let floorShare: CGFloat = 1.0 / 8

    /// The far end's share of the anchor at `fade` percent: 100 is
    /// `floorShare`, 0 the anchor itself (#2569).
    nonisolated static func farShare(fade: CGFloat) -> CGFloat {
        let strength =
            KiwiShelf.clampFillFade(fade)
            / KiwiShelf.fillFadeRange.upperBound
        return 1 - strength * (1 - floorShare)
    }

    /// The two ends a stored Fill renders as on glass — the anchor
    /// clamped to `maxAlpha`, the floor `farShare` of it — `nil`
    /// where the Fill is transparent or the OS draws no glass.
    ///
    /// **Private, and that is the guard.** Every surface reaches a
    /// colour through `apply`, so the compiler holds what a scan
    /// would otherwise have to police. A sibling channel taking the
    /// raw Fill beside this clamp is what #1297 was — `GlassPlate`
    /// set `tintColor` that way.
    @MainActor
    private static func rendered(
        _ fill: GlassFill
    ) -> (anchor: NSColor, floor: NSColor)? {
        let hex = fill.hex
        // The one drawing authority, not a second `#available`
        // beside it: nothing here touches a macOS 26 API, so the
        // check is policy rather than the compiler's (#1374).
        guard LiquidGlassGate.drawsGlass, !hex.isEmpty else {
            return nil
        }
        let color = NSColor(kiwiHex: hex)
        guard color.alphaComponent > 0 else { return nil }
        let anchor = min(color.alphaComponent, maxAlpha)
        return (
            color.withAlphaComponent(anchor),
            color.withAlphaComponent(anchor * farShare(fade: fill.fade))
        )
    }

    /// The fade's direction in the layer's unit space (y up):
    /// from the shelf's screen `edge` toward the windows; `.top`
    /// is downward, a surface on no edge's by ruling (#1620).
    nonisolated static func fade(
        from edge: AppBarEdge
    ) -> (start: CGPoint, end: CGPoint) {
        switch edge {
        case .top: (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case .bottom: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        case .left: (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case .right: (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        }
    }

    /// The variant a Fill pins on the glass: `.darkAqua` for a dark
    /// Fill, `nil` — the app's appearance, `NSApp.appearance` as the
    /// Settings pick writes it — for a light or transparent one. The
    /// threshold is `wantsLightInk`'s; hue decides, an alpha above
    /// zero does not. Only dark is pinned because only dark CAN be:
    /// measured on macOS 26.6.2 under a light app appearance, `.aqua`
    /// leaves the material adapting (#1308; the argument is in
    /// `docs/design-decisions.md` ▸ Liquid Glass).
    @MainActor
    private static func pinnedAppearance(
        _ hex: String
    ) -> NSAppearance? {
        guard LiquidGlassGate.drawsGlass, !hex.isEmpty else {
            return nil
        }
        let fill = NSColor(kiwiHex: hex)
        guard fill.alphaComponent > 0, fill.wantsLightInk else {
            return nil
        }
        return NSAppearance(named: .darkAqua)
    }

    /// Pins `glass` dark where there is no Fill to decide it:
    /// KiwiVision's plate, whose dim is always black (#2103).
    @MainActor
    static func pinDark(_ glass: NSView) {
        glass.appearance = NSAppearance(named: .darkAqua)
    }

    /// Pins `glass` dark where `host` — the window's effective
    /// appearance, which carries the Settings Appearance pick —
    /// resolves dark, and lifts the pin otherwise: the Space-switch
    /// plates, which have no Fill and follow KiwiHub's glass. Only
    /// dark is pinned, for `pinnedAppearance`'s reason (#2539).
    @MainActor
    static func followPick(_ glass: NSView, host: NSAppearance) {
        let dark = host.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        glass.appearance = dark ? NSAppearance(named: .darkAqua) : nil
    }

    /// Makes the backdrop `glass`'s content — above the material,
    /// beneath what the glass hosts (#2569) — and colours it,
    /// fading from `edge` — the shelf's screen edge, or `.top` for
    /// a surface on none (#1620, #1621) — toward the windows
    /// (#1622), clear where the Fill reaches no colour, and pins
    /// the glass's variant from the same Fill (#1308). It takes the
    /// Fill rather than a colour so the cap cannot be walked around
    /// at a call site (#1297); `fill.fade` sets how far it fades.
    /// An EMPTY Fill is no colour — clear glass, nothing pinned —
    /// while any other string resolves through `NSColor(kiwiHex:)`.
    @MainActor
    static func apply(
        _ backdrop: GlassBackdrop,
        in glass: NSView,
        cornerRadius: CGFloat,
        fill: GlassFill,
        edge: AppBarEdge
    ) {
        paint(
            backdrop,
            in: glass,
            cornerRadius: cornerRadius,
            fill: fill,
            fadeFrom: edge
        )
    }

    /// A READING surface's tint: the Fill at the anchor's capped
    /// alpha over the whole surface, no fade — the ruled exception
    /// to #1620's detached-surface fade, since a panel of text must
    /// stay legible over its whole height (owner, #1946: the bar
    /// hover peek). Everything else `apply` holds holds here.
    @MainActor
    static func applyUniform(
        _ backdrop: GlassBackdrop,
        in glass: NSView,
        cornerRadius: CGFloat,
        fill: GlassFill
    ) {
        paint(
            backdrop,
            in: glass,
            cornerRadius: cornerRadius,
            fill: fill,
            fadeFrom: nil
        )
    }

    /// The one painter both doors take: a fade from `edge`, or the
    /// anchor alone where it is nil. A clear Fill clears the
    /// gradient and never hides the backdrop, which carries the
    /// glass's content.
    @MainActor
    private static func paint(
        _ backdrop: GlassBackdrop,
        in glass: NSView,
        cornerRadius: CGFloat,
        fill: GlassFill,
        fadeFrom edge: AppBarEdge?
    ) {
        glass.appearance = pinnedAppearance(fill.hex)
        GlassPlate.setBackdrop(glass, backdrop)
        guard let gradient = backdrop.gradient else { return }
        gradient.cornerRadius = cornerRadius
        guard let ends = rendered(fill) else {
            gradient.colors = nil
            return
        }
        let direction = fade(from: edge ?? .top)
        gradient.startPoint = direction.start
        gradient.endPoint = direction.end
        let far = edge == nil ? ends.anchor : ends.floor
        gradient.colors = [ends.anchor.cgColor, far.cgColor]
    }
}
