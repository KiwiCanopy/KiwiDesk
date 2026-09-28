import SwiftUI

/// Scrolling's part in a tour story (#1750): which window a
/// focus step lands on, and the clip that lets a pan slide.
extension ScrollingSchematic {
    /// The slot holding focus, `focusStep` windows from the
    /// resting one; the incoming window is stepped over, and a
    /// step past the row's end stops at its last window.
    var focusIndex: Int {
        let placed = row
        let direction = focusStep > 0 ? 1 : -1
        var index = 0
        var left = abs(focusStep)
        while left > 0 {
            let next = index + direction
            guard placed.slots.contains(next) else { break }
            index = next
            if lone || tellsStory || next != placed.incoming {
                left -= 1
            }
        }
        return index
    }
}

/// A story's strip is clipped at the screen edge, so a window
/// panned past it slides out of view; elsewhere the canvas's own
/// clip stands (`SchematicCanvas.screen`).
struct StoryClip: ViewModifier {
    let clips: Bool

    func body(content: Content) -> some View {
        if clips { content.clipped() } else { content }
    }
}
