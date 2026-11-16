import Foundation

/// The wire shape both types share (#1656):
/// `natural_scrolling: { trackpad, mouse }`, `long_swipes`, and the
/// base's alone, `step_length`. The base takes a default for every
/// key a file does not carry; the override writes only what it sets.
enum ScrollGestureKeys: String, CodingKey {
    case naturalScrolling = "natural_scrolling"
    case longSwipes = "long_swipes"
    case stepLength = "step_length"
}

enum NaturalScrollingKeys: String, CodingKey {
    case trackpad, mouse
}

extension ScrollGestureOverride: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ScrollGestureKeys.self)
        if c.contains(.naturalScrolling) {
            let n = try c.nestedContainer(
                keyedBy: NaturalScrollingKeys.self,
                forKey: .naturalScrolling
            )
            naturalTrackpad = try n.decodeIfPresent(
                NaturalScrolling.self,
                forKey: .trackpad
            )
            naturalMouse = try n.decodeIfPresent(
                NaturalScrolling.self,
                forKey: .mouse
            )
        }
        longSwipes = try c.decodeIfPresent(Bool.self, forKey: .longSwipes)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ScrollGestureKeys.self)
        if naturalTrackpad != nil || naturalMouse != nil {
            var n = c.nestedContainer(
                keyedBy: NaturalScrollingKeys.self,
                forKey: .naturalScrolling
            )
            try n.encodeIfPresent(naturalTrackpad, forKey: .trackpad)
            try n.encodeIfPresent(naturalMouse, forKey: .mouse)
        }
        try c.encodeIfPresent(longSwipes, forKey: .longSwipes)
    }
}

extension ScrollGestureBase: Codable {
    /// Decoded as an override over the defaults, so the group is
    /// additive key by key.
    public init(from decoder: Decoder) throws {
        self = try ScrollGestureOverride(from: decoder)
            .resolved(onto: .defaults)
        let c = try decoder.container(keyedBy: ScrollGestureKeys.self)
        stepLength =
            try c.decodeIfPresent(Double.self, forKey: .stepLength)
            ?? Self.defaults.stepLength
    }

    /// Every key, always: `gui.json` states the whole base.
    public func encode(to encoder: Encoder) throws {
        try ScrollGestureOverride(
            naturalTrackpad: naturalTrackpad,
            naturalMouse: naturalMouse,
            longSwipes: longSwipes
        ).encode(to: encoder)
        var c = encoder.container(keyedBy: ScrollGestureKeys.self)
        try c.encode(stepLength, forKey: .stepLength)
    }
}
