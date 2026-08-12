import SwiftUI

/// The grant step's "still waiting" mark: a small amber dot that
/// breathes (#828, the prototype's own indicator).
///
/// It replaced a `lock.shield` glyph, which was legible but inert
/// — a static padlock says "locked", not "watching". The pulse is
/// the honest part: the page really is polling for the grant and
/// really does continue by itself, and a moving mark is what says
/// so to someone who has just been sent to another app.
///
/// **Hue is not the channel here, and this does not reopen that
/// ruling.** What the tree shipped once was a raw `.green` /
/// `.orange` hero pair where colour was the ONLY difference
/// between two states. This dot is 9 pt inside the instruction
/// card, under a sentence that says "waiting"; the granted state
/// is a 38 pt check in the middle of the screen with a sentence
/// of its own. Shape, size, position and words all differ before
/// colour says anything.
///
/// `warningInk`, not a raw amber: it is the theme's attention
/// token, and its light value is darkened for contrast, which a
/// fixed `#E0A34A` would not be on this card.
struct WaitingDot: View {
    /// Reduce Motion is a system setting an app does not argue
    /// with. The dot still draws — losing the mark entirely would
    /// leave the sentence unmarked — it simply stops moving, and
    /// rests at the strength the pulse would spend most of its
    /// time near rather than at either extreme.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private let size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(SettingsTheme.warningInk)
            .frame(width: size, height: size)
            .opacity(opacity)
            .animation(pulse, value: breathing)
            .onAppear { breathing = true }
            .accessibilityHidden(true)
    }

    private var opacity: Double {
        guard !reduceMotion else { return 0.8 }
        return breathing ? 0.35 : 1
    }

    private var pulse: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 1.1).repeatForever(
            autoreverses: true
        )
    }
}
