import AppKit
import Combine
import SwiftUI

/// One opening of a KiwiDesk key panel — Jump to window or the
/// shortcuts overview — and whether its close has begun (owner
/// eyeball, 2026-10-12): both panels arrive and leave alike.
@MainActor
final class PanelPresence: ObservableObject {
    @Published private(set) var leaving = false
    /// How long the fade out takes.
    static let leaveDuration: TimeInterval = 0.15

    /// Starts the fade, then orders `panel` out once it lands — at
    /// once under Reduce Motion — unless a later opening of the
    /// same panel took it over meanwhile.
    func fadeOut(
        _ panel: NSWindow?,
        reduceMotion: Bool,
        stillCurrent: @escaping @MainActor (PanelPresence) -> Bool
    ) {
        leaving = true
        let delay = reduceMotion ? 0 : Self.leaveDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            [weak self, weak panel] in
            guard let self, stillCurrent(self) else { return }
            panel?.orderOut(nil)
        }
    }
}

/// Spotlight's entrance: the panel grows in from slightly smaller,
/// and shrinks as it leaves; under Reduce Motion it is simply
/// there, and gone. Scale only — the glass never takes an
/// opacity: a group opacity renders it offscreen over black, and
/// the glass then adapts dark and keeps it (#1308's mechanism).
private struct PanelEntrance: ViewModifier {
    @ObservedObject var presence: PanelPresence
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared && !presence.leaving ? 1 : 0.94)
            .animation(
                reduceMotion
                    ? nil : .easeIn(duration: PanelPresence.leaveDuration),
                value: presence.leaving
            )
            .onAppear {
                withAnimation(
                    reduceMotion ? nil : .spring(duration: 0.22, bounce: 0)
                ) {
                    appeared = true
                }
            }
    }
}

/// The panel's CONTENT fading in and out with the entrance, inside
/// the glass, which keeps its full opacity.
private struct PanelContentFade: ViewModifier {
    @ObservedObject var presence: PanelPresence
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared && !presence.leaving ? 1 : 0)
            .animation(
                reduceMotion
                    ? nil : .easeIn(duration: PanelPresence.leaveDuration),
                value: presence.leaving
            )
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// The scale half, applied OUTSIDE the glass.
    func panelEntrance(_ presence: PanelPresence) -> some View {
        modifier(PanelEntrance(presence: presence))
    }

    /// The fade half, applied to the content INSIDE the glass.
    func panelContentFade(_ presence: PanelPresence) -> some View {
        modifier(PanelContentFade(presence: presence))
    }
}
