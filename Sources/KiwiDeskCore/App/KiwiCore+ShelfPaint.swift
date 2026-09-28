import Foundation

/// The welcome tour's live look (#1720): a look or a palette
/// painted THROUGH — onto the running settings and, while a saved
/// profile is live, into that profile's file, non-adopting — so a
/// click is the whole act. The file half reads the stored settings
/// and paints them, never `persistProfile`'s live capture (#1179).
extension KiwiCore {
    /// What a tour Revert returns to: the settings live and in the
    /// file before the first paint, and whose profile they were.
    public struct ShelfPaintBaseline: Equatable, Sendable {
        let profile: String?
        let live: TilingSettings
        let stored: TilingSettings?
    }

    /// Records what a later `restoreShelf` returns to.
    public func shelfPaintBaseline() -> ShelfPaintBaseline {
        let name = profiles.currentName
        return ShelfPaintBaseline(
            profile: name,
            live: tiler.settings,
            stored: name.flatMap { try? profiles.read(name: $0).settings }
        )
    }

    /// Whether `baseline` still describes the live profile.
    public func describesLiveProfile(_ baseline: ShelfPaintBaseline) -> Bool {
        baseline.profile == profiles.currentName
    }

    /// `settings` with `look` and its palette painted on, or —
    /// with no look — `palette`'s colours alone, keeping the shape.
    public static func painted(
        _ settings: TilingSettings,
        look: ShelfLook?,
        palette: ColorPalette?
    ) -> TilingSettings {
        var painted = settings
        if let look {
            look.apply(to: &painted, palette: palette)
        } else {
            palette?.apply(to: &painted)
        }
        return painted
    }

    /// Paints a pick live and into the live profile's file.
    public func paintShelf(look: ShelfLook?, palette: ColorPalette?) {
        let paint: (inout TilingSettings) -> Void = {
            $0 = Self.painted($0, look: look, palette: palette)
        }
        paintShelfThrough(live: paint, stored: paint)
    }

    /// Returns what a paint can reach to `baseline`, live and in
    /// the file; refused once another profile is live.
    @discardableResult
    public func restoreShelf(_ baseline: ShelfPaintBaseline) -> Bool {
        guard describesLiveProfile(baseline) else { return false }
        paintShelfThrough(
            live: { $0 = Self.unpainted($0, to: baseline.live) },
            stored: { settings in
                guard let stored = baseline.stored else { return }
                settings = Self.unpainted(settings, to: stored)
            }
        )
        return true
    }

    /// `current` with everything a paint reaches returned to
    /// `before` and nothing else: the look's and the palette's keys,
    /// then the writes `ShelfLook.apply` makes beyond its keys —
    /// every glass leaf, the drag strokes the Borders masters own,
    /// the per-layout indicators — put back too
    /// (`ShelfPaintRoundTripTests`).
    static func unpainted(
        _ current: TilingSettings,
        to before: TilingSettings
    ) -> TilingSettings {
        var settings = painted(
            current,
            look: ShelfLook(
                name: "",
                palette: nil,
                style: LookKeys.extract(from: before)
            ),
            palette: ColorPalette(
                name: "",
                colors: ColorPaletteKeys.extract(from: before)
            )
        )
        for leaf in TilingSettings.liquidGlassLeaves {
            settings[keyPath: leaf] = before[keyPath: leaf]
        }
        settings.dragGhost.borderWidth = before.dragGhost.borderWidth
        settings.dragDropZone.borderWidth =
            before.dragDropZone.borderWidth
        settings.dragCornerRadius = before.dragCornerRadius
        settings.monocle.appBar.activeIndicator =
            before.monocle.appBar.activeIndicator
        settings.scrolling.appBar.activeIndicator =
            before.scrolling.appBar.activeIndicator
        return settings
    }

    private func paintShelfThrough(
        live: (inout TilingSettings) -> Void,
        stored: (inout TilingSettings) -> Void
    ) {
        live(&tiler.settings)
        if let name = profiles.currentName {
            writeStoredSettings(name, stored)
        }
        // An explicit apply (§5): a look can move the shelf's edge.
        retile(pass: .apply)
        onShelfPainted()
    }

    /// Non-adopting, like `overwriteProfile`: `current` and
    /// `dirty` stay as they were.
    private func writeStoredSettings(
        _ name: String,
        _ paint: (inout TilingSettings) -> Void
    ) {
        do {
            var profile = try profiles.read(name: name)
            paint(&profile.settings)
            try profiles.write(profile)
            refreshConfigIssues()
        } catch {
            onLog("tour look: profile \(name) not written: \(error)")
        }
    }
}
