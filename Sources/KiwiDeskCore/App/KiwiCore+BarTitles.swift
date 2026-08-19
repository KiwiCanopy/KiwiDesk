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

    /// Folds a `.windowTitleChanged` into the bars, or drops it.
    ///
    /// Dropping is the common case and has to stay cheap: most
    /// title events belong to a window on another Desktop, to a
    /// bar whose content draws no text, or to a bar that is not
    /// on screen at all.
    func handleTitleChangedForBars(_ id: WindowID) {
        guard barsDrawTitle(of: id) else { return }
        deferred.schedule(
            .barTitleRefresh,
            after: Self.barTitleRefreshDelay
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

    /// Whether any bar currently on screen would draw this
    /// window's title.
    ///
    /// Both halves ask the RENDERED content, not the stored
    /// preference: a vertical bar collapses to icon-only
    /// (`Content.rendered(horizontal:)`), so a title change
    /// under one must schedule nothing at all rather than
    /// re-render a bar that cannot show it.
    /// Space Bar first, deliberately: it is three bool reads and
    /// one comparison, while the App Bar half builds an
    /// `effectiveTiledMembers` array per shown display. On every
    /// title event, the cheap question deserves to answer first.
    private func barsDrawTitle(of id: WindowID) -> Bool {
        spaceBarDrawsTitle(of: id) || appBarDrawsTitle(of: id)
    }

    /// True when `id` is a bar item on a space that is showing,
    /// under a resolved content that draws text.
    ///
    /// A collapsed group draws its app name, never a member's
    /// title (`barItemText`), so a title change inside one
    /// changes nothing on screen — but resolving that here would
    /// mean rebuilding the groups for every keystroke, which
    /// costs more than the refresh it would save. The cheap
    /// membership question is the right altitude; the expensive
    /// one is answered once, in the refresh itself.
    private func appBarDrawsTitle(of id: WindowID) -> Bool {
        for space in showingSpaces() {
            guard let host = barHost(for: space),
                host.appBar.enabled
            else { continue }
            let style = host.resolvedBar(
                global: tiler.settings.appBarStyle
            )
            guard
                style.content.rendered(
                    horizontal: style.edge.isHorizontal
                ).showsText
            else { continue }
            if state.effectiveTiledMembers(
                of: space,
                activeSpace: activeSpace?.id
            ).contains(id) {
                return true
            }
        }
        return false
    }

    /// True when the Space Bar's front segment is drawing this
    /// window. That segment shows the focused window of the
    /// space on its display, so only a focused window's title
    /// can be on screen there — and only on a horizontal bar,
    /// where `layoutFrontName` draws text at all.
    private func spaceBarDrawsTitle(of id: WindowID) -> Bool {
        let style = tiler.settings.spaceBarStyle
        guard style.enabled, style.showFrontApp,
            style.edge.isHorizontal
        else { return false }
        return showingSpaces().contains { $0.focused == id }
    }

    /// The spaces whose bars are actually painted right now.
    ///
    /// Three rules, and all three must match what the drivers
    /// (`KiwiCore+AppBar.bar(for:)`, `KiwiCore+SpaceBar
    /// .spaceBar(for:)`) apply, or this gate refuses refreshes
    /// they would have rendered, or schedules ones they discard:
    /// the CURRENT space per display, the #670 fullscreen
    /// stand-down (a fullscreen desktop paints no bar at all),
    /// and the cold-start fallback to the active space before
    /// the display list seeds.
    ///
    /// The drivers re-derive rather than call this because each
    /// needs more than the space — a screen, a bar host, a
    /// resolved style. `BarTitleRefreshTests` pins the agreement
    /// from this side; a driver that changes one of the three
    /// owes this function the same change.
    private func showingSpaces() -> [Space] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            guard NativeSpaces.activeSpaceIsUser() else {
                return []
            }
            return activeSpace.map { [$0] } ?? []
        }
        return displays.compactMap { display in
            guard
                NativeSpaces.currentSpaceIsUser(
                    display: display.id
                )
            else { return nil }
            return state.workspaces.currentSpace(on: display.id)
                .flatMap { state.workspaces[$0] }
        }
    }
}
