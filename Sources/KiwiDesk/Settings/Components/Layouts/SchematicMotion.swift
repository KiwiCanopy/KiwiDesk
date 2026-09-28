import SwiftUI

/// Where a schematic stands inside a tour story (#1750). `.rest`
/// is the frame every other surface draws; the tour tweens from a
/// story's start to it, and Reduce Motion only ever shows it.
struct SchematicMotion: Equatable {
    /// Scrolling: the slot holding focus, counted from the resting
    /// focus; the row rests wherever the engine pans it for that
    /// focus. A step landing on the incoming window skips past it.
    var focus = 0
    /// Monocle: the front card's turn in half-turns about the
    /// focus axis; any whole number is the resting card.
    var turn: Double = 0
    /// Floating: how far the front window's drag has come, 0 at
    /// the pick-up and 1 where it is left.
    var drag: Double = 1

    static let rest = SchematicMotion()
}

private struct SchematicRestageKey: EnvironmentKey {
    static let defaultValue = LayoutSchematic.damping
}

private struct SchematicTellsStoryKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether a schematic draws a story's frame (#1750): no `+`
    /// slot to step over, and windows past the screen edge drawn
    /// and clipped there so a pan slides them rather than
    /// dropping them.
    var schematicTellsStory: Bool {
        get { self[SchematicTellsStoryKey.self] }
        set { self[SchematicTellsStoryKey.self] = newValue }
    }

    /// How a schematic restages a value change: the live-slider
    /// damping by default, the tour's slower story pace (#1750).
    /// Every reader gates it on Reduce Motion itself.
    var schematicRestage: Animation {
        get { self[SchematicRestageKey.self] }
        set { self[SchematicRestageKey.self] = newValue }
    }
}
