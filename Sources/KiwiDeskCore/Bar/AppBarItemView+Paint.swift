import AppKit

/// How an App Bar item paints itself: the colour ladder (hover
/// over active over rest), the box fill, the corner rounding and
/// the active accent. Split from AppBarItemView.swift, which sat
/// on the §2.1 file ceiling.
///
/// One concern, deliberately: every one of these reads `style`
/// plus the item's own `isActive` / `isHovered` state and writes
/// a layer property. Click, drag and hover *bookkeeping* stays
/// with the view; what a hover then LOOKS like is here.
extension AppBarItemView {
    /// Hover swaps the box background (no overlay: a wash on
    /// top would muddy the icon and text) and the text color.
    func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        glyphLabel.textColor = NSColor(kiwiHex: textColorHex)
        // The app image never tints, so it carried no active
        // cue at all (QA 2026-07-19): dimmed when inactive,
        // shape (accent) plus opacity carry the state.
        // Deliberately the full 0.4 dim, NOT the Space Bar's
        // 0.6 middle tier — this is a binary signal reinforced
        // by the outline, with no lower tier to collide with
        // (see `BarAccent.activeUnfocusedAlpha`).
        iconView.alphaValue =
            isActive || isHovered
            ? 1 : style.dimFactor
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        applyCornerRadius()
    }

    /// The item's bar-cross dimension (its thickness), which the
    /// corner radius resolves against.
    var crossThickness: CGFloat {
        horizontal ? bounds.height : bounds.width
    }

    /// Round the box fill to `cornerRoundness`% of a capsule, and
    /// clip the active mark to the same corner through `accentClip`
    /// so it cuts on the curve like the Space Bar (owner 2026-07-20)
    /// instead of a square end — the item itself does NOT clip, so a
    /// corner count badge stays whole. Which corners round follows
    /// `maskedCorners`.
    func applyCornerRadius() {
        let radius = style.resolvedCornerRadius(
            forThickness: crossThickness
        )
        layer?.cornerRadius = radius
        accentClip.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = radius
        accentClip.layer?.maskedCorners = maskedCorners
    }

    /// Boxed clips all four corners (each item is its own box). Plain
    /// clips only where the shared plate actually rounds — the run's
    /// outer end — so the mark cuts on the curve there and runs
    /// square (touching a neighbour) between (owner 2026-07-20). The
    /// horizontal run maps the outer end to the X side (flip-safe);
    /// the vertical run to the Y side.
    var maskedCorners: CACornerMask {
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

    var textColorHex: String {
        if isHovered { return style.hoverItemColor }
        return isActive
            ? style.activeItemColor
            : style.itemColor
    }

    /// Whether this item paints a box behind its content: always
    /// when `boxed`, and on hover (a `plain` item reveals a box
    /// only while hovered). `plain` is otherwise boxless in every
    /// combo, including the active ring (which is a pure stroke).
    var hasBox: Bool {
        if isHovered { return true }
        return style.hasBox
    }

    // The Settings palette scene (`PaletteSceneThumbnail`, GUI
    // target) is a schematic twin of this box/accent logic —
    // keep the two in step when the box or accent rules change.
    // It replaced `AppBarPreviewStrip`, which drew the same
    // twin and was retired in #793.
    var boxColorHex: String {
        if isHovered { return style.hoverFillColor }
        // One fill for every box (active marked by the indicator,
        // not a distinct fill). Plain — and any glass finish, whose
        // shared plate is the background — paint no per-item box.
        return style.hasBox ? style.fillColor : "#00000000"
    }

    /// How the active item is marked, gated on the indicator and
    /// orthogonal to `backgroundStyle` (the background no longer
    /// secretly picks the accent). Only the active item, and never
    /// under `gap` (its slot is hidden entirely).
    enum AccentMode { case none, outline, edgeMark }

    var accentMode: AccentMode {
        guard isActive, style.activeIndicator != .gap else {
            return .none
        }
        return style.activeIndicator == .outline
            ? .outline : .edgeMark
    }

    /// The ring and edge mark both live on the `accent` subview
    /// (mutually exclusive); geometry is set in `layoutAccent`.
    /// The ring is a pure stroke (no fill) in the highlight
    /// color; the edge mark a filled bar.
    func applyAccent() {
        layer?.borderWidth = 0
        switch accentMode {
        case .none:
            accent.isHidden = true
        case .outline:
            accent.isHidden = false
            accent.layer?.borderWidth = 2
            accent.layer?.borderColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
            accent.layer?.backgroundColor =
                NSColor.clear.cgColor
        case .edgeMark:
            accent.isHidden = false
            accent.layer?.borderWidth = 0
            accent.layer?.backgroundColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
        }
    }
}
