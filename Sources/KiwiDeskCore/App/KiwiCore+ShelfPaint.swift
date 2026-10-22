import Foundation

/// The welcome tour's live look (#1720): a look or a palette
/// painted THROUGH — onto the running settings and, while a saved
/// profile is live, into that profile's file, non-adopting — so a
/// click is the whole act. The file half reads the stored settings
/// and paints them, never `persistProfile`'s live capture (#1179).
extension KiwiCore {
    /// What a tour Revert returns to — the looks step's and the
    /// bars step's (#2515): the settings live and in the file
    /// before the step's first write, and whose profile they were.
    public struct TourBaseline: Equatable, Sendable {
        let profile: String?
        let live: TilingSettings
        let stored: TilingSettings?
    }

    /// Records what a later `restoreShelf` returns to.
    public func tourBaseline() -> TourBaseline {
        let name = profiles.currentName
        return TourBaseline(
            profile: name,
            live: tiler.settings,
            stored:
                name
                .flatMap { try? profiles.read(name: $0) }
                .map(resolvedSettings(of:))
        )
    }

    /// Whether `baseline` still describes the live profile.
    public func describesLiveProfile(_ baseline: TourBaseline) -> Bool {
        baseline.profile == profiles.currentName
    }

    /// `settings` with `look` painted on, its colours included,
    /// then `palette`'s colours over them — the later pick wins
    /// (#1752).
    public static func painted(
        _ settings: TilingSettings,
        look: ShelfLook?,
        palette: ColorPalette?
    ) -> TilingSettings {
        var painted = settings
        // A paint reaches styling and colours, never motion (#2176).
        look?.stylingOnly.apply(to: &painted)
        palette?.apply(to: &painted)
        return painted
    }

    /// Paints a pick live and into the live profile's file.
    public func paintShelf(look: ShelfLook?, palette: ColorPalette?) {
        let paint: (inout TilingSettings) -> Void = {
            $0 = Self.painted($0, look: look, palette: palette)
        }
        writeTourEditThrough(live: paint, stored: paint)
    }

    /// Returns what a paint can reach to `baseline`, live and in
    /// the file; refused once another profile is live.
    @discardableResult
    public func restoreShelf(_ baseline: TourBaseline) -> Bool {
        guard describesLiveProfile(baseline) else { return false }
        writeTourEditThrough(
            live: { $0 = Self.unpainted($0, to: baseline.live) },
            stored: { settings in
                guard let stored = baseline.stored else { return }
                settings = Self.unpainted(settings, to: stored)
            }
        )
        return true
    }

    /// `current` with everything a paint reaches returned to
    /// `before` and nothing else: the look's styling — never its
    /// motion, which a paint does not reach (#2176) — and colours,
    /// then the writes `ShelfLook.apply` makes beyond its keys —
    /// every glass leaf, the per-layout indicators — put back too
    /// (`ShelfPaintRoundTripTests`).
    static func unpainted(
        _ current: TilingSettings,
        to before: TilingSettings
    ) -> TilingSettings {
        var settings = painted(
            current,
            look: ShelfLook(
                name: "",
                style: LookKeys.extract(
                    from: before,
                    paths: LookKeys.styling
                ),
                colors: ColorPaletteKeys.extract(from: before)
            ),
            palette: nil
        )
        for leaf in TilingSettings.liquidGlassLeaves {
            settings[keyPath: leaf] = before[keyPath: leaf]
        }
        for leaf in TilingSettings.layoutIndicatorLeaves {
            settings[keyPath: leaf] = before[keyPath: leaf]
        }
        return settings
    }

    /// Writes a tour step's edit live, retiles, and writes it
    /// into the live profile's file.
    func writeTourEditThrough(
        live: (inout TilingSettings) -> Void,
        stored: @escaping SettingsEdit
    ) {
        live(&tiler.settings)
        // An explicit apply (§5): a look can move the shelf's edge.
        retile(pass: .apply)
        writeThroughLiveProfile(.settings(stored))
    }
}
