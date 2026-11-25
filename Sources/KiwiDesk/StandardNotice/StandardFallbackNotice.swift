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
    /// tour owns the screen. A count recorded on this Mac never
    /// shows again, so a screen connected mid-tour is not
    /// announced later — the trade for never showing the notice
    /// at an unrelated moment after the tour.
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

    /// `show` is the seam a test reads; the app shows the window.
    static func present(
        _ fallback: StandardFallback,
        tourShowing: Bool,
        defaults: UserDefaults = AppDefaults.store,
        show: (StandardFallbackNotice) -> Void = { $0.show() }
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
        show(StandardFallbackNotice(fallback))
    }

    /// The notice's window, built but not shown: the update
    /// window's alert-sized chrome (`UpdateCheckingWindowController`
    /// is the template), titled for VoiceOver and the Window menu.
    static func makeWindow(
        screenCount: Int,
        onOK: @escaping () -> Void
    ) -> NSWindow {
        let view = StandardFallbackView(
            screenCount: screenCount,
            onOK: onOK
        )
        let probe = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let window = UpdateWindowChrome.window(
            root: view,
            height: probe.fittingSize.height + UpdateWindowMetrics.titleBar,
            width: StandardFallbackView.width
        )
        window.title = StandardFallbackWords.title(screenCount)
        // Above the bars, as the tour is once its grant lands.
        window.level = BarPanel.aboveLevel
        return window
    }

    private init(_ fallback: StandardFallback) {
        self.fallback = fallback
    }

    private func show() {
        Self.open = self
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
