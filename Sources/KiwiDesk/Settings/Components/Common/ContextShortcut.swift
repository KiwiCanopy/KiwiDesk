import SwiftUI

/// Keyboard shortcut to open the contextual menu for a focused
/// row or element (#845).
///
/// macOS has no standard key that opens a focused control's
/// contextual menu, so actions behind `.contextMenu` alone were
/// unreachable without a mouse or VoiceOver. A zero-size hidden
/// `Menu` with `.keyboardShortcut` binds the chord (`⌃.` /
/// Control-Period) on the focused element without adding visual
/// clutter or intercepting mouse drags for `.draggable` rows.
extension View {
    /// Opens `menu` when the focused element receives the
    /// context-menu keyboard shortcut (`⌃.`).
    @ViewBuilder
    func contextShortcut<Content: View>(
        @ViewBuilder _ menu: () -> Content
    ) -> some View {
        background(alignment: .topLeading) {
            Menu {
                menu()
            } label: {
                EmptyView()
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .keyboardShortcut(".", modifiers: .control)
            .accessibilityHidden(true)
        }
    }
}
