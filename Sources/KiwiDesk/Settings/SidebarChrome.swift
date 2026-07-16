import AppKit
import SwiftUI

/// The source-list vibrancy a `NavigationSplitView` sidebar gets
/// for free. The settings shell composes its columns with a plain
/// `HStack` instead (#297 — the split view's divider cannot be
/// locked on macOS 26), so the sidebar column re-creates the
/// translucent backdrop itself: this sits behind the list, whose
/// own scroll background is hidden.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Not `.sidebar`: that pulls strong desktop color through
        // the card. System Settings' floating pane reads as the
        // same neutral gray as the detail column, just subtly
        // translucent — `.underWindowBackground` matches that.
        view.material = .underWindowBackground
        // Within the window, not behind it: the card must read
        // as a gray pane over the window's own background, not
        // let the desktop bleed through.
        view.blendingMode = .withinWindow
        // Pinned active: the sidebar's background swap (flat
        // gray when `controlActiveState == .inactive`) is the
        // single owner of the inactive transition. Following
        // the window here would half-dim the material in the
        // carved-out window-active-but-not-key case (shared
        // color panel up) and double-dim mid-crossfade.
        view.state = .active
        return view
    }

    func updateNSView(
        _ nsView: NSVisualEffectView,
        context: Context
    ) {}
}

/// Fades sidebar chrome while the window is inactive — the
/// treatment System Settings gives its colored sidebar icons:
/// a plain alpha fade that keeps the hue, never a desaturate
/// (settled by eye — grayscale reads as "disabled"). The list
/// rows dim through vibrancy on their own; this exists for the
/// hand-built pieces above them: identity header, search field,
/// icon tiles (#297). Deliberately keyed to `.inactive` only —
/// `.active` (window not key, app still active, e.g. while the
/// shared color panel is up) must not dim the sidebar.
struct InactiveDimmed: ViewModifier {
    /// The one fade shared by the card's background swap and
    /// every dimmed element — they key off the same state
    /// change and must stay in lockstep.
    static let fade = Animation.easeInOut(duration: 0.15)

    @Environment(\.controlActiveState) private var activeState

    func body(content: Content) -> some View {
        content
            .opacity(activeState == .inactive ? 0.5 : 1)
            .animation(Self.fade, value: activeState)
    }
}

extension View {
    func inactiveDimmed() -> some View {
        modifier(InactiveDimmed())
    }
}
