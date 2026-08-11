import AppKit
import KiwiDeskCore
import SwiftUI

/// The one-time mark that points at the real menu-bar item after
/// the tour closes (#678 Phase 4 pass 11, turn 15a).
///
/// The window vanishing is the moment someone wonders where the
/// app went, and a picture inside a closed window cannot answer
/// that — so the answer has to be on the desktop, beside the
/// thing it names.
///
/// **It skips itself when it cannot be honest.** #331 retired a
/// *timed* menu-bar popover because it fails under an auto-hidden
/// menu bar, and a coach mark inherits that defect exactly: it
/// would point at a strip that is not on screen. The repair is
/// the skip, not a redesign — with the menu bar hidden the
/// closing card's sentence is what teaches where the app lives,
/// and it survives a hidden menu bar where any picture does not.
/// Owner ruling, 2026-08-11.
///
/// It shows **once, ever** and dismisses on any click.
@MainActor
final class MenuBarCoachMark {
    private static let shownKey = "onboardingCoachMarkShown"

    private var window: NSWindow?
    private var monitors: [Any] = []

    static var hasShown: Bool {
        UserDefaults.standard.bool(forKey: shownKey)
    }

    /// Whether the mark can point at something the user can see.
    ///
    /// Two ways it cannot, and both are ordinary configurations
    /// rather than failures: the menu bar auto-hides, or the item
    /// has no on-screen button — which is what a menu-bar manager
    /// parking it off the visible strip looks like from here.
    static func canPoint(at button: NSStatusBarButton?) -> Bool {
        guard !GeometryUtils.menuBarAutoHides else { return false }
        guard let window = button?.window else { return false }
        guard let screen = window.screen else { return false }
        return screen.frame.intersects(window.frame)
    }

    /// Shows the mark under `button`, or does nothing at all —
    /// silently, because every reason to skip is a state the user
    /// chose.
    func show(under button: NSStatusBarButton?) {
        guard !Self.hasShown, Self.canPoint(at: button),
            let anchor = button?.window?.frame
        else { return }
        UserDefaults.standard.set(true, forKey: Self.shownKey)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary,
        ]
        let host = NSHostingView(
            rootView: LocaleScopedRoot {
                MenuBarCoachMarkView()
            }
            .environmentObject(LocalizationManager.shared)
        )
        panel.contentView = host
        let size = host.fittingSize
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(
            CGPoint(
                x: min(
                    anchor.midX - size.width / 2,
                    (panel.screen ?? NSScreen.main)?.frame.maxX
                        ?? anchor.maxX
                ),
                y: anchor.minY - 6
            )
        )
        panel.orderFrontRegardless()
        window = panel
        watchForDismissal()
    }

    /// Any click dismisses — inside the app or out. Both monitors
    /// are needed: the local one never sees a click on another
    /// app, and the global one never sees a click on ours.
    private func watchForDismissal() {
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
        ]
        monitors.append(
            NSEvent.addGlobalMonitorForEvents(matching: mask) {
                [weak self] _ in
                self?.dismiss()
            } as Any
        )
        monitors.append(
            NSEvent.addLocalMonitorForEvents(matching: mask) {
                [weak self] event in
                self?.dismiss()
                return event
            } as Any
        )
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }
}

/// The mark's content: the real menu-bar symbol and one sentence.
///
/// The mark must be the SAME glyph the menu bar shows, or it
/// points at something the user cannot match to what they see.
private struct MenuBarCoachMarkView: View {
    var body: some View {
        HStack(spacing: 8) {
            if let icon = BrandAssets.menuBarIcon {
                Image(nsImage: icon)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "menubar.arrow.up.rectangle")
            }
            Text(
                L(
                    "onboarding.coach_mark.body",
                    "KiwiDesk lives up here. Click it for Settings "
                        + "and help."
                )
            )
            .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .frame(maxWidth: 320)
        .accessibilityElement(children: .combine)
    }
}
