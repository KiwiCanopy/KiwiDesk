import AppKit

/// The Fill as KiwiHub and the plates wear it over their frost
/// where no Liquid Glass draws (#2569 ▸ amendment): one flat colour
/// at the Fill's own alpha, full alpha under Reduce transparency.
/// Minted only by `KiwiShelf.frostFill(opaque:)`.
public struct FrostFill: Sendable, Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    /// The scheme the frost and its content take from the Fill.
    public let pin: GlassPaint.Pin

    fileprivate init(_ rgba: HexColor.RGBA, opaque: Bool) {
        red = rgba.red
        green = rgba.green
        blue = rgba.blue
        alpha = opaque ? 1 : rgba.alpha
        let fill = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        pin = fill.wantsLightInk ? .dark : .light
    }
}

/// What KiwiHub, the cue plates, the Space-switch slide plates and
/// the brief pocket's plate draw on (#2569).
public enum PanelGround: Sendable, Equatable {
    /// The untinted look: frosted glass or the material.
    case untinted
    /// The Fill on `.clear` glass, fading.
    case glass
    /// The Fill flat over the material.
    case frost(FrostFill)

    /// The Fill worn over the material, nil on any other ground.
    public var frost: FrostFill? {
        if case .frost(let fill) = self { fill } else { nil }
    }
}

extension KiwiShelf {
    /// Whether "Tint KiwiHub and plates" is on with a Fill that
    /// has a colour.
    public var panelsWearFill: Bool { tintHubAndPlates && hasFill }

    /// The Fill flat over a panel's material; nil where it has no
    /// colour. `opaque` is Reduce transparency.
    public func frostFill(opaque: Bool) -> FrostFill? {
        guard hasFill, let rgba = HexColor.parse(fillColor) else {
            return nil
        }
        return FrostFill(rgba, opaque: opaque)
    }

    /// The Fill a Core plate's glass wears on `ground`: the shelf's
    /// on glass, nil on any other ground.
    public func glassFill(on ground: PanelGround) -> GlassFill? {
        ground == .glass ? glassFill : nil
    }

    /// The one answer for every panel that wears the Fill.
    /// `glassDrawn` is the caller's read of KiwiHub's leaf as drawn
    /// — `LiquidGlassGate.rendered(glass:)` in Core, `PanelGlass`
    /// under the live Reduce transparency in the GUI — so the
    /// decision stays pure.
    public func panelGround(
        glassDrawn: Bool,
        reduceTransparency: Bool
    ) -> PanelGround {
        guard panelsWearFill,
            let frost = frostFill(opaque: reduceTransparency)
        else { return .untinted }
        return glassDrawn ? .glass : .frost(frost)
    }
}
