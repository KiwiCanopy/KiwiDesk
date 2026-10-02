import AppKit

/// A font installed or removed while KiwiDesk runs (#1681): the
/// one observer forgets what `BarFont` read, then re-draws both
/// bars, whose refresh re-derives the missing-family issue. Wired
/// in `start()` and retired in `stop()`, symmetric like Reduce
/// transparency; the token lives on `AppBarManager`
/// (`fontSetObserver`) and the handler body is named so a test can
/// drive it without the notification.
extension KiwiCore {
    func wireFontSet() {
        retireFontSet()
        appBars.fontSetObserver = NotificationCenter.default.addObserver(
            forName: NSFont.fontSetChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fontSetDidChange() }
        }
    }

    func retireFontSet() {
        guard let token = appBars.fontSetObserver else { return }
        NotificationCenter.default.removeObserver(token)
        appBars.fontSetObserver = nil
    }

    /// The observer body: what the fonts were, forgotten; then the
    /// bars, whose refresh carries the issue.
    func fontSetDidChange() {
        BarFont.invalidate()
        updateBars()
    }
}
