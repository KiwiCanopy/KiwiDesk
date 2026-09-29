import Foundation

/// The wire shape both types share (#1656): `pan`, `space_step`,
/// `natural_scrolling: { trackpad, mouse }`, `long_swipes`,
/// `step_distance`. The base takes a default for every key a file
/// does not carry; the override writes only what it sets.
enum ScrollGestureKeys: String, CodingKey {
    case pan
    case spaceStep = "space_step"
    case naturalScrolling = "natural_scrolling"
    case longSwipes = "long_swipes"
    case stepDistance = "step_distance"
}

enum NaturalScrollingKeys: String, CodingKey {
    case trackpad, mouse
}

extension ScrollGestureOverride: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ScrollGestureKeys.self)
        pan = try c.decodeIfPresent(ScrollChord.self, forKey: .pan)
        spaceStep = try c.decodeIfPresent(
            ScrollChord.self,
            forKey: .spaceStep
        )
        if c.contains(.naturalScrolling) {
            let n = try c.nestedContainer(
                keyedBy: NaturalScrollingKeys.self,
                forKey: .naturalScrolling
            )
            naturalTrackpad = try n.decodeIfPresent(
                Bool.self,
                forKey: .trackpad
            )
            naturalMouse = try n.decodeIfPresent(Bool.self, forKey: .mouse)
        }
        longSwipes = try c.decodeIfPresent(Bool.self, forKey: .longSwipes)
        stepDistance = try c.decodeIfPresent(
            Double.self,
            forKey: .stepDistance
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ScrollGestureKeys.self)
        try c.encodeIfPresent(pan, forKey: .pan)
        try c.encodeIfPresent(spaceStep, forKey: .spaceStep)
        if naturalTrackpad != nil || naturalMouse != nil {
            var n = c.nestedContainer(
                keyedBy: NaturalScrollingKeys.self,
                forKey: .naturalScrolling
            )
            try n.encodeIfPresent(naturalTrackpad, forKey: .trackpad)
            try n.encodeIfPresent(naturalMouse, forKey: .mouse)
        }
        try c.encodeIfPresent(longSwipes, forKey: .longSwipes)
        try c.encodeIfPresent(stepDistance, forKey: .stepDistance)
    }
}

extension ScrollGestureBase: Codable {
    /// Decoded as an override over the defaults, so the group is
    /// additive key by key.
    public init(from decoder: Decoder) throws {
        self = try ScrollGestureOverride(from: decoder)
            .resolved(onto: .defaults)
    }

    /// Every key, always: `gui.json` states the whole base.
    public func encode(to encoder: Encoder) throws {
        try ScrollGestureOverride(
            pan: pan,
            spaceStep: spaceStep,
            naturalTrackpad: naturalTrackpad,
            naturalMouse: naturalMouse,
            longSwipes: longSwipes,
            stepDistance: stepDistance
        ).encode(to: encoder)
    }
}
