import AppKit
import Combine
import SwiftUI

/// One opening of a KiwiDesk key panel — Jump to window or the
/// shortcuts overview — and whether its close has begun (owner
/// eyeball, 2026-10-12): both panels arrive and leave alike.
@MainActor
final class PanelPresence: ObservableObject {
    @Published private(set) var leaving = false
    /// KiwiDesk's Reduce Motion for this opening, read by the host
    /// once at show (#3252): the fade's order-out and the views'
    /// gates read this one value, so they never disagree.
    let reduceMotion: Bool

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    /// How long the fade out takes.
    static let leaveDuration: TimeInterval = 0.15
    /// A held panel's alpha: at 0 a window passes clicks through
    /// (measured 2026-11-11, macOS 27.2), so it keeps a trace.
    nonisolated static let holdAlpha: CGFloat = 0.01

    /// Starts the fade, then orders `panel` out once it lands — at
    /// once under this opening's Reduce Motion — unless a later
    /// opening of the same panel took it over meanwhile. Where
    /// `holdUnseen` runs past the fade the panel stays up, unseen,
    /// until it ends, so a double click's second press lands on it
    /// (#3209).
    func fadeOut(
        _ panel: NSWindow?,
        holdUnseen: TimeInterval,
        stillCurrent: @escaping @MainActor (PanelPresence) -> Bool
    ) {
        leaving = true
        let delay = reduceMotion ? 0 : Self.leaveDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            [weak self, weak panel] in
            guard let self, stillCurrent(self) else { return }
            let rest = holdUnseen - delay
            guard rest > 0 else {
                panel?.orderOut(nil)
                return
            }
            panel?.ignoresMouseEvents = false
            panel?.alphaValue = Self.holdAlpha
            DispatchQueue.main.asyncAfter(deadline: .now() + rest) {
                [weak self, weak panel] in
                guard let self, stillCurrent(self) else { return }
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
    }

    /// The hold's clock in uptime seconds, a seam over the host read.
    static var uptime: () -> TimeInterval = {
        ProcessInfo.processInfo.systemUptime
    }

    /// `clickHold` for the event being handled now on `panel`; read
    /// at the press, since a close may finish a turn later.
    static func clickHoldNow(on panel: NSWindow?) -> TimeInterval {
        clickHold(
            after: NSApp?.currentEvent,
            on: panel?.windowNumber,
            now: uptime(),
            interval: NSEvent.doubleClickInterval
        )
    }

    /// How long a close holds its panel up: what is left of the
    /// double-click interval after the release on the panel
    /// `window` that made it, and nothing for a close no click on it
    /// made. Times are uptime seconds, `NSEvent.timestamp`'s clock.
    static func clickHold(
        after event: NSEvent?,
        on window: Int?,
        now: TimeInterval,
        interval: TimeInterval
    ) -> TimeInterval {
        guard let event, event.type == .leftMouseUp,
            event.windowNumber == window
        else { return 0 }
        return max(0, interval - (now - event.timestamp))
    }
}

/// Spotlight's entrance: the panel grows in from slightly smaller,
/// and shrinks as it leaves; under Reduce Motion it is simply
/// there, and gone. Scale only — the glass never takes an
/// opacity: a group opacity renders it offscreen over black, and
/// the glass then adapts dark and keeps it (#1308's mechanism).
private struct PanelEntrance: ViewModifier {
    @ObservedObject var presence: PanelPresence
    @State private var appeared = false
    @State private var settled = false
    private var reduceMotion: Bool { presence.reduceMotion }

    func body(content: Content) -> some View {
        content
            .environment(\.panelSettled, settled || reduceMotion)
            .scaleEffect(appeared && !presence.leaving ? 1 : 0.94)
            .animation(
                reduceMotion
                    ? nil : .easeIn(duration: PanelPresence.leaveDuration),
                value: presence.leaving
            )
            .onAppear {
                withAnimation(
                    reduceMotion ? nil : .spring(duration: 0.22, bounce: 0),
                    completionCriteria: .removed
                ) {
                    appeared = true
                } completion: {
                    settled = true
                }
            }
    }
}

/// The panel's CONTENT fading in and out with the entrance, inside
/// the glass, which keeps its full opacity.
private struct PanelContentFade: ViewModifier {
    @ObservedObject var presence: PanelPresence
    @State private var appeared = false
    private var reduceMotion: Bool { presence.reduceMotion }

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

extension EnvironmentValues {
    /// The Reduce Motion a view's host decided at show (#3252):
    /// `ReduceMotion.isOn` for a desk surface. True where no host
    /// wrote it, so a forgotten host draws still for everyone
    /// rather than moving under Off; `ReduceMotionHomeTests` holds
    /// the hosts.
    @Entry var kiwiDeskReduceMotion = true

    /// False while a key panel's entrance is still scaling it in
    /// (#3203): the scale rounds a scroll inside a few points off
    /// its rest, so a list settles back once this turns true. True
    /// wherever no entrance runs, and under Reduce Motion.
    @Entry var panelSettled = true
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
