import Foundation

/// Keeping drawn window titles current.
///
/// The bars are driven from `retile()`, which fires on every
/// structural, focus, mode and settings change — and a title
/// change is none of those. `TilingEngine.shouldRetile` returns
/// false for `.windowTitleChanged` deliberately (a title moves
/// no window), so before titles were drawable nothing needed to
/// happen and nothing did. Drawing a title makes the same event
/// a *render* input, so it needs this path — and needs it to
/// stay off the retile path, which would move windows for a
/// renamed tab.
///
/// Debounced, because the event is as fast as a keystroke: an
/// editor retitles as its dirty flag flips and a browser several
/// times through a page load. One refresh per quiet moment is
/// both cheaper and steadier to look at — an App Bar re-measures
/// its uniform slot against the widest title on every render
/// (`AppBarOverlay.autoSlotWidth`), so an undebounced burst would
/// visibly pump the slot widths while the user types.
///
/// It rides `DeferredTasks` rather than a flag plus a dispatch
/// hop: the reschedule-cancels-the-previous protocol IS the
/// debounce, and teardown's `cancelAll()` then reaches this the
/// same as every other settle — a hand-kept cancel list is how a
/// missing cancel slipped through review once already (#48).
extension KiwiCore {
    /// How long a title change waits for its neighbours.
    ///
    /// The wait restarts on each further change, so a burst
    /// refreshes once when it STOPS rather than once when it
    /// starts. Both readings are defensible; this one is
    /// steadier to look at, because the alternative repaints
    /// immediately and then goes stale for the rest of the
    /// burst. Long enough that a page load or a save lands as
    /// one refresh, short enough that the bar still reads as
    /// live when the user pauses.
    ///
    /// Not a settle deadline, and nothing is verified after it:
    /// a missed refresh costs a stale label until the next
    /// change, never a wrong window position.
    static let barTitleRefreshDelay = Duration.milliseconds(200)

    /// Maximum time a continuous burst of title changes may delay
    /// the bar refresh before one is forced (#900).
    static let barTitleRefreshMaxWait = Duration.seconds(1)

    /// Folds a `.windowTitleChanged` into the bars, or drops it.
    ///
    /// Dropping is the common case and has to stay cheap: most
    /// title events belong to a window on another Desktop, to a
    /// collapsed group (which shows its app name), or to a bar
    /// that is not on screen at all. Content is deliberately
    /// not a drop reason (#937): an icon-only bar announces the
    /// title it does not draw, so those events ride the
    /// debounce above instead of being dropped.
    func handleTitleChangedForBars(_ id: WindowID) {
        guard barsShowTitle(of: id) else { return }
        deferred.schedule(
            .barTitleRefresh,
            after: Self.barTitleRefreshDelay,
            maxWait: Self.barTitleRefreshMaxWait
        ) { [weak self] in
            self?.runBarTitleRefresh()
        }
    }

    /// The refresh body — named so a test drives it without
    /// waiting out the debounce (the `runSizeBoundProbe` and
    /// `runBorderResync` precedent).
    ///
    /// Re-renders the bars and nothing else. Deliberately not
    /// `retile()`: a title carries no geometry, so retiling on
    /// one would re-issue a frame set (and, on an app that
    /// refuses a size, re-teach the #677 ledger) every time a
    /// tab was renamed.
    func runBarTitleRefresh() {
        updateAppBar()
        updateSpaceBar()
    }

    /// Whether any bar on screen right now is showing this
    /// window's title — drawing it, or announcing it.
    ///
    /// Asked of the bars the managers actually PAINTED, never
    /// re-derived from state. That is the obligation the float
    /// clamp already carries for bar geometry
    /// (`KiwiCore+FloatClamp`: strips come from `shownStrips`,
    /// "never re-derived here — a second derivation drifts from
    /// what is on screen"), and this gate is the argument for
    /// it: it shipped with a three-rule copy of a five-gate
    /// policy and disagreed with the Space Bar driver on its
    /// first day (review 2026-08-20). The painted record folds
    /// in every rule for free — the #670 fullscreen stand-down,
    /// the per-display screen pick, the empty-bar suppression,
    /// the App Bar's cold-start fallback and the Space Bar's
    /// deliberate lack of one — so no driver can change one of
    /// them out from under this file.
    ///
    /// Cheap, as the drop path must be: two walks over at most
    /// one bar per display, and no machine read at all. The
    /// version this replaced called the WindowServer twice per
    /// event (`NativeSpaces.currentSpaceIsUser` enumerates every
    /// display's every space), on the main actor, BEFORE the
    /// debounce — once per keystroke in an editor.
    ///
    /// Space Bar first: it compares one optional per painted
    /// bar, while the App Bar half walks that bar's items.
    private func barsShowTitle(of id: WindowID) -> Bool {
        spaceBars.showsTitle(of: id) || appBars.showsTitle(of: id)
    }
}
