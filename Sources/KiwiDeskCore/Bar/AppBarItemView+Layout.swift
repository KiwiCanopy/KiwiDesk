import AppKit

/// Slot layout: icon and name centered as one group, font
/// scaled with the bar thickness, name-only truncation.
extension AppBarItemView {
    override func layout() {
        super.layout()
        applyCornerRadius()
        layoutAccent()
        if horizontal {
            layoutHorizontal()
        } else {
            layoutVertical()
        }
        layoutBadge()
    }

    /// The group-count badge: a filled circle just after the
    /// content, growing into a larger circle for multi-digit counts.
    private func layoutBadge() {
        guard !badge.isHidden else { return }
        // 0.32/9: same QA 2026-07-19 shrink decision as the
        // Space Bar badge (whose numbers differ deliberately —
        // it scales off the glyph cell, this off the slot) —
        // the 0.38 ratio with a 10pt floor read oversized next
        // to small icons.
        let baseHeight = min(
            max(
                min(bounds.width, bounds.height) * 0.32,
                9
            ),
            14
        )
        badge.font = .systemFont(
            ofSize: baseHeight * 0.9,
            weight: .bold
        )
        // Ensure text fits centered; width must equal height
        // to maintain a proper circle. We add minimal horizontal
        // padding to keep the badge tight around the text.
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = max(baseHeight, textWidth + 2)
        // With a name shown, sit just after it at its top corner —
        // not over it (overlapping text reads badly). Icon- or
        // glyph-only: overlap the top-right corner like a
        // notification badge (owner 2026-07-20). Clamped to the slot.
        let x: CGFloat
        let y: CGFloat
        if !label.isHidden, label.frame.width > 0 {
            x = label.frame.maxX + 2
            y = label.frame.minY - diameter / 3
        } else {
            let box =
                !glyphLabel.isHidden
                ? glyphLabel.frame
                : (!iconView.isHidden ? iconView.frame : bounds)
            x = box.maxX - diameter / 2
            y = box.minY - diameter / 2
        }
        badge.frame = CGRect(
            x: min(max(x, 0), bounds.width - diameter),
            y: min(max(y, 0), bounds.height - diameter),
            width: diameter,
            height: diameter
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    /// Shared with the overlay's natural-width measurement.
    nonisolated static let contentPadding: CGFloat = 4
    /// The slot's own leading/trailing inset — a touch wider
    /// than the inner content padding (manual QA 2026-07-18);
    /// shared with the natural-width measurement so widening
    /// it can never re-truncate the widest name.
    nonisolated static let edgePadding: CGFloat = 6

    /// `bar_font_size` 0 = auto: scale with the bar's cross
    /// dimension (its thickness), so a fat bar gets readable
    /// text and a slim one stays inside its strip.
    private var effectiveFontSize: CGFloat {
        if style.fontSize > 0 {
            return style.fontSize
        }
        return Self.autoFontSize(
            forThickness: horizontal
                ? bounds.height : bounds.width
        )
    }

    nonisolated static func autoFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        min(max(thickness * 0.42, 9), 28)
    }

    /// Icon and name sit centered in the slot as one group;
    /// when space runs out, only the name shrinks — the icon
    /// always survives.
    private func layoutHorizontal() {
        let pad = Self.contentPadding
        let edge = Self.edgePadding
        let font = NSFont.systemFont(ofSize: effectiveFontSize)
        label.font = font
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = name
        let side =
            iconSlotHidden
            ? 0
            : max(
                min(bounds.height, bounds.width) - pad * 2,
                0
            )
        // The cell itself knows how much room the name needs;
        // measuring the raw string undershoots the cell's own
        // padding and truncates names that would have fit.
        var textSize =
            style.content == .icon
            ? .zero
            : (label.cell?.cellSize ?? .zero)
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        // Horizontal-only path, so the raw preference IS the
        // rendered content here.
        let showText = style.content != .icon
        // Half a pad: the full pad read too airy between icon
        // and name (manual QA 2026-07-18).
        var spacing: CGFloat =
            side > 0 && showText ? pad / 2 : 0
        textSize.width = min(
            textSize.width,
            bounds.width - side - spacing - edge * 2
        )
        if textSize.width < 8 {
            textSize.width = 0
            spacing = 0
        }
        label.isHidden = !showText || textSize.width == 0
        // The edge floor exists for text; an icon-only tab at
        // the minimum slot keeps the tighter pad so its glyph
        // box can't poke past the trailing border.
        var x = max(
            (bounds.width - side - spacing - textSize.width)
                / 2,
            showText ? edge : pad
        )
        if !iconSlotHidden {
            layoutIconSlot(
                in: CGRect(
                    x: x,
                    y: (bounds.height - side) / 2,
                    width: side,
                    height: side
                )
            )
            x += side + spacing
        }
        label.frame = CGRect(
            x: x,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
    }

    /// Vertical bars render icon-only (QA 2026-07-19): names
    /// letter-stacked terribly and rotated text is not native,
    /// so `Content.rendered(horizontal:)` collapses the
    /// preference to `.icon` and the label never shows here
    /// (`configure` hides it).
    private func layoutVertical() {
        let pad = Self.contentPadding
        let side =
            iconSlotHidden
            ? 0
            : max(
                min(bounds.width, bounds.height) - pad * 2,
                0
            )
        guard side > 0 else { return }
        layoutIconSlot(
            in: CGRect(
                x: (bounds.width - side) / 2,
                y: max((bounds.height - side) / 2, pad),
                width: side,
                height: side
            )
        )
    }

    private func layoutAccent() {
        guard !accent.isHidden else { return }
        switch accentMode {
        case .ring: layoutRing()
        case .edgeMark: layoutEdgeMark()
        case .none: break
        }
    }

    /// A boxed ring hugs the box (flush, same corner radius); a
    /// plain ring insets a couple points and reads as a capsule
    /// outline — a clean native selection mark that keeps `plain`
    /// boxless (ui-designer 2026-07-14).
    private func layoutRing() {
        if style.hasBox {
            accent.frame = bounds
            accent.layer?.cornerRadius =
                style.resolvedCornerRadius(
                    forThickness: crossThickness
                )
        } else {
            // The plain ring is a full capsule by design —
            // intentionally roundness-independent (there's no box
            // whose corners it should match), so it reads as a
            // clean selection outline rather than a fake pill.
            let inset = BarAccent.capsuleInset
            accent.frame = bounds.insetBy(dx: inset, dy: inset)
            accent.layer?.cornerRadius =
                min(accent.frame.height, accent.frame.width) / 2
        }
    }

    /// A ~3pt bar spanning the slot's full window-facing edge
    /// (flipped coordinates: y grows downward): a top bar faces
    /// down, a bottom bar up, a left bar right, a right bar left.
    /// Full-width, no corner inset — matching the Space Bar's mark
    /// (owner call 2026-07-20).
    private func layoutEdgeMark() {
        accent.layer?.cornerRadius = 0
        let thickness: CGFloat = 3
        switch edge {
        case .top:
            accent.frame = CGRect(
                x: 0,
                y: bounds.height - thickness,
                width: bounds.width,
                height: thickness
            )
        case .bottom:
            accent.frame = CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: thickness
            )
        case .left:
            accent.frame = CGRect(
                x: bounds.width - thickness,
                y: 0,
                width: thickness,
                height: bounds.height
            )
        case .right:
            accent.frame = CGRect(
                x: 0,
                y: 0,
                width: thickness,
                height: bounds.height
            )
        }
    }

}
