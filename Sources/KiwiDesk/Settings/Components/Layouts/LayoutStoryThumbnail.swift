import KiwiDeskCore
import SwiftUI

/// A layout thumbnail that plays its `LayoutStory` once when it
/// first appears and again on each replay, then rests (#1750).
/// It never loops, and under Reduce Motion it never leaves the
/// rest frame. Only a surface that is read rather than compared
/// hosts one; the Layouts chooser and its panel stay at rest.
struct LayoutStoryThumbnail: View {
    let mode: LayoutMode
    let settings: TilingSettings
    let scale: SchematicScale
    /// Wait before the first play, for a staggered list.
    var delay: Double = 0
    /// Changed by the host to play again (a hover on its row).
    var replay = 0
    /// Plays again when the pointer enters the thumbnail itself,
    /// for a host with no row of its own to hover.
    var replaysOnHover = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var atStart = false
    @State private var appeared = false
    @State private var run = 0

    /// One story's pace, window counts included.
    static let pace = Animation.easeInOut(duration: 1.1)
    /// How long the start frame holds before it moves.
    static let lead = 0.35

    /// The story, resting on the ruled count every host shares.
    var story: LayoutStory {
        .of(mode, resting: LayoutStory.restingWindows(for: mode))
    }

    var body: some View {
        let frame = atStart ? story.start : story.rest
        LayoutSchematicView(
            mode: mode,
            settings: settings,
            windows: frame.windows,
            scale: scale,
            motion: frame.motion
        )
        .environment(\.schematicRestage, Self.pace)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            play(after: delay)
        }
        .onChange(of: replay) { _, _ in play(after: 0) }
        .onHover { inside in
            if inside && replaysOnHover { play(after: 0) }
        }
    }

    /// Jumps to the start frame, holds it, then eases to rest; a
    /// newer play supersedes a pending one.
    private func play(after wait: Double) {
        guard !reduceMotion, story.plays else { return }
        run += 1
        let token = run
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) { atStart = true }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + wait + Self.lead
        ) {
            guard token == run else { return }
            withAnimation(reduceMotion ? nil : Self.pace) {
                atStart = false
            }
        }
    }
}
