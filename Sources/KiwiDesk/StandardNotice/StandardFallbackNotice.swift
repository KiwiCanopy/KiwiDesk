import AppKit
import KiwiDeskCore
import SwiftUI

/// The screen counts this Mac already showed the Standard notice
/// for (#3646). This Mac's state, never config: it does not travel
/// with the config folder or a backup.
enum StandardFallbackShown {
    static let key = "standard_fallback.shown_counts"

    static func wasShown(_ count: Int, in defaults: UserDefaults) -> Bool {
        shown(in: defaults).contains(count)
    }

    static func markShown(_ count: Int, in defaults: UserDefaults) {
        var counts = shown(in: defaults)
        guard !counts.contains(count) else { return }
        counts.append(count)
        defaults.set(counts, forKey: key)
    }

    private static func shown(in defaults: UserDefaults) -> [Int] {
        (defaults.array(forKey: key) as? [Int]) ?? []
    }
}

/// The once-per-count notice that a screen change set up the
/// Standard's Spaces (#3646). It comes forward like the update
/// window, by the owner's ruling, and offers no choice.
@MainActor
final class StandardFallbackNotice: NSObject, NSWindowDelegate {
    private(set) static var open: StandardFallbackNotice?

    let fallback: StandardFallback
    private var window: NSWindow?

    /// Whether the notice for `count` shows now, recording the
    /// count either way it is answered: shown, or held while the
    /// tour owns the screen, which already narrates the Spaces on
    /// it. A count recorded on this Mac never shows again.
    static func admit(
        count: Int,
        tourShowing: Bool,
        defaults: UserDefaults
    ) -> Bool {
        guard !StandardFallbackShown.wasShown(count, in: defaults)
        else { return false }
        StandardFallbackShown.markShown(count, in: defaults)
        return !tourShowing
    }

    static func present(
        _ fallback: StandardFallback,
        tourShowing: Bool,
        defaults: UserDefaults = AppDefaults.store
    ) {
        guard
            admit(
                count: fallback.screenCount,
                tourShowing: tourShowing,
                defaults: defaults
            )
        else { return }
        // A newer count replaces the notice still up.
        open?.window?.close()
        let notice = StandardFallbackNotice(fallback)
        open = notice
        notice.show()
    }

    /// The notice's window, built but not shown.
    static func makeWindow(
        screenCount: Int,
        onOK: @escaping () -> Void
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = StandardFallbackWords.title(screenCount)
        window.contentView = NSHostingView(
            rootView: LocaleScopedRoot {
                StandardFallbackView(
                    screenCount: screenCount,
                    onOK: onOK
                )
            }
            .environmentObject(LocalizationManager.shared)
            .environment(\.kiwiDeskReduceMotion, ReduceMotion.isOn)
        )
        window.setContentSize(window.contentView?.fittingSize ?? .zero)
        // Above the bars, as the tour is once its grant lands.
        window.level = BarPanel.aboveLevel
        window.isReleasedWhenClosed = false
        return window
    }

    private init(_ fallback: StandardFallback) {
        self.fallback = fallback
    }

    private func show() {
        let window = Self.makeWindow(
            screenCount: fallback.screenCount
        ) { [weak self] in self?.window?.close() }
        window.delegate = self
        window.center()
        self.window = window
        NSApp.forceFront(window)
    }

    func windowWillClose(_ notification: Notification) {
        if Self.open === self { Self.open = nil }
    }
}
