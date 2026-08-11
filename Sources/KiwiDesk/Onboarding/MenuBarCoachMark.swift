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
    /// **The rule, stated over facts rather than over AppKit**, so
    /// the owner's ruling is assertable: the mark is built, and it
    /// skips itself when it would point at nothing. Three ways it
    /// would, and all three are ordinary configurations rather
    /// than failures:
    ///
    /// - the menu bar auto-hides, which is the defect #331 retired
    ///   a timed popover for and which a coach mark inherits
    ///   whole;
    /// - the item has no button at all — no real status item, as
    ///   behind the test seam;
    /// - the button's window sits outside its screen, which is
    ///   what a menu-bar manager parking the item off the visible
    ///   strip looks like from here.
    static func canPoint(
        menuBarAutoHides: Bool,
        button: CGRect?,
        screen: CGRect?
    ) -> Bool {
        guard !menuBarAutoHides else { return false }
        guard let button, let screen else { return false }
        return screen.intersects(button)
    }

    /// The live face of the rule above.
    static func canPoint(at button: NSStatusBarButton?) -> Bool {
        canPoint(
            menuBarAutoHides: GeometryUtils.menuBarAutoHides,
            button: button?.window?.frame,
            screen: button?.window?.screen?.frame
        )
    }

    /// Shows the mark under `button`, or does nothing at all —
    /// silently, because every reason to skip is a state the user
    /// chose.
    func show(under button: NSStatusBarButton?) {
        guard !Self.hasShown, Self.canPoint(at: button),
            let anchor = button?.window?.frame,
            // The anchor's OWN screen. Asking the panel for one
            // before positioning it resolves the display holding
            // the global origin — the MAIN screen — so with the
            // menu bar on a second display the mark was clamped
            // hundreds of points from the item it points at
            // (code review, 2026-08-11).
            let screen = button?.window?.screen?.frame
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
        // `setFrameTopLeftPoint` takes the panel's LEFT edge, so
        // the right limit is the screen's max minus the panel's
        // own width — and there is a left edge to respect too, for
        // an item near the start of the bar.
        let centred = anchor.midX - size.width / 2
        let rightLimit = screen.maxX - size.width
        panel.setFrameTopLeftPoint(
            CGPoint(
                x: min(
                    max(centred, screen.minX),
                    max(rightLimit, screen.minX)
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
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: mask,
            handler: { [weak self] _ in self?.dismiss() }
        ) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: mask,
            handler: { [weak self] event in
                self?.dismiss()
                return event
            }
        ) {
            monitors.append(local)
        }
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
                    "KiwiDesk lives up here. Click it for "
                        + "Settings and your shortcuts."
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
