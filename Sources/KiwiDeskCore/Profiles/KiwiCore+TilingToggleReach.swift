import Foundation

/// The tiling toggle's reach families on a Save (#3089): each
/// profile's own value lands in its `settings.tiling`, the shared
/// value in `gui.json`'s app-wide `tiling` group — the one door a
/// Settings write of a base takes, so it retiles as the verbs do.
extension KiwiCore {
    /// Writes `name`'s own start and hide values from the tables:
    /// nil where the profile follows the base.
    func writeTilingToggle(
        start: RuleReachTable<Bool>,
        hides: RuleReachTable<Bool>,
        for name: String,
        into settings: inout TilingToggleSettings
    ) {
        let base = appWideSettled
        typealias Table = RuleReachTable<Bool>
        if !(start.touched[name] ?? []).isEmpty {
            settings.start = start.tilingOverride(
                Table.tilingStartKey,
                for: name,
                fallback: base.tilingStartGlobal
            )
        }
        let touched = hides.touched[name] ?? []
        if touched.contains(Table.offHidesBordersKey) {
            settings.offHidesBorders = hides.tilingOverride(
                Table.offHidesBordersKey,
                for: name,
                fallback: base.tilingOffHidesBorders
            )
        }
        if touched.contains(Table.offHidesBarsKey) {
            settings.offHidesBars = hides.tilingOverride(
                Table.offHidesBarsKey,
                for: name,
                fallback: base.tilingOffHidesBars
            )
        }
    }

    /// After a Save's files landed: stores each touched base
    /// app-wide and has the live profile's own values follow the
    /// file just written. A moved start base or live start lays the
    /// Spaces out, even where the live profile's own value hides
    /// the change — an explicit apply, as the `tiling.*` verbs'
    /// (AGENTS.md §5); a moved tick only repaints what it hides.
    func settleTilingToggle(
        start: RuleReachTable<Bool>,
        hides: RuleReachTable<Bool>,
        written: [Profile]
    ) {
        typealias Table = RuleReachTable<Bool>
        let live = profiles.currentName.flatMap { name in
            let touched =
                !(start.touched[name] ?? []).isEmpty
                || !(hides.touched[name] ?? []).isEmpty
            return touched ? written.first { $0.name == name } : nil
        }
        let bases = start.baseTouched.union(hides.baseTouched)
        guard !bases.isEmpty || live != nil else { return }
        if !bases.isEmpty {
            let settled = appWideSettled
            setAppWide(persisting: true) {
                if bases.contains(Table.tilingStartKey) {
                    $0.tilingStartGlobal = start.tilingBase(
                        Table.tilingStartKey,
                        fallback: settled.tilingStartGlobal
                    )
                }
                if bases.contains(Table.offHidesBordersKey) {
                    $0.tilingOffHidesBorders = hides.tilingBase(
                        Table.offHidesBordersKey,
                        fallback: settled.tilingOffHidesBorders
                    )
                }
                if bases.contains(Table.offHidesBarsKey) {
                    $0.tilingOffHidesBars = hides.tilingBase(
                        Table.offHidesBarsKey,
                        fallback: settled.tilingOffHidesBars
                    )
                }
            }
        }
        var startMoved = bases.contains(Table.tilingStartKey)
        if let stored = live?.settings.tiling {
            // The file is the truth now, so a later base change
            // reaches live too. This repaint covers the profile's
            // own ticks; a moved hide base also repaints through
            // `appWideLiveChanged`, idempotently.
            var toggle = tiler.settings.tiling
            startMoved = startMoved || toggle.start != stored.start
            toggle.start = stored.start
            toggle.offHidesBorders = stored.offHidesBorders
            toggle.offHidesBars = stored.offHidesBars
            if toggle != tiler.settings.tiling {
                tiler.settings.tiling = toggle
                if !startMoved { repaintTilingOffStandDowns() }
            }
        }
        if startMoved { retile(pass: .apply) }
    }
}
