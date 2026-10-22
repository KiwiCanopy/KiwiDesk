import AppKit

/// Drives the overflow marks (#2235 ▸ Ruling — the overflow mark):
/// one per run end that hides windows, read off the engine's own
/// record of what each shown Space's runs drew (`runCovers`) and
/// wearing KiwiShelf's look, so a shelf write repaints them with
/// the bars.
extension KiwiCore {
    /// `reassertOrder` re-stacks every mark, as the settle passes
    /// do for the rings (#2026).
    func updateOverflowMarks(reassertOrder: Bool = false) {
        let specs = overflowMarkSpecs()
        // Ahead of the sync, whose order gate reads this request's
        // verdict (#1925).
        windowServer.request(
            Set(specs.map(\.mark.anchor)),
            for: .overflow
        )
        overflowMarks.sync(specs, reassertOrder: reassertOrder)
    }

    /// One spec per run end that hides windows on a shown Space.
    func overflowMarkSpecs() -> [OverflowMarkManager.Spec] {
        let shelf = LiquidGlassGate.rendered(tiler.settings.kiwishelf)
        let shown = Set(state.workspaces.visibleSpaces)
        let carried = stickyReachCarried()
        // A mark wears the shelf's look, so it stands down with the
        // shelf: native fullscreen, a show or a maximized window in
        // front (#1787, #2448).
        return tiler.runCovers.values
            .filter { cover in
                guard shown.contains(cover.space),
                    let screen = TilingEngine.screen(
                        for: cover.space,
                        in: state
                    )
                else { return false }
                return !shelfStandsDown(on: screen)
            }
            .sorted { $0.space.description < $1.space.description }
            .flatMap(OverflowMark.marks(of:))
            .compactMap { mark in
                guard let window = state.windows[mark.anchor] else {
                    return nil
                }
                return OverflowMarkManager.Spec(
                    mark: mark,
                    frame: window.frame,
                    name: Self.overflowMarkName(mark),
                    shelf: shelf,
                    spans: carried.contains(mark.anchor)
                )
            }
    }

    /// VoiceOver's name: the direction and the count, count last
    /// and one key per direction, since a direction word may have
    /// to agree with its sentence.
    static func overflowMarkName(_ mark: OverflowMark) -> String {
        switch mark.end {
        case .top:
            L("overflow_mark.ax.above", "More windows above: %1$d", mark.count)
        case .bottom:
            L("overflow_mark.ax.below", "More windows below: %1$d", mark.count)
        case .left:
            L(
                "overflow_mark.ax.left",
                "More windows to the left: %1$d",
                mark.count
            )
        case .right:
            L(
                "overflow_mark.ax.right",
                "More windows to the right: %1$d",
                mark.count
            )
        }
    }

    /// The marks' peek and menu seams, wired once at boot; their
    /// WindowServer stream is wired with the others'
    /// (`connectWindowServerConsumers`).
    func wireOverflowMarks() {
        overflowMarks.peek = shelves.peek
        overflowMarks.openMenu = { [weak self] mark, anchor in
            self?.presentBarWindowMenu(
                mark.windows,
                kind: .overflow,
                space: mark.space,
                at: anchor
            )
        }
    }
}
