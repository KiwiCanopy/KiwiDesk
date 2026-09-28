import Foundation

/// The welcome tour's live look (#1720): a paint of KiwiShelf's
/// styling or colours written THROUGH — onto the running settings
/// and, while a saved profile is live, into that profile's file —
/// so a click is the whole act and nothing is left to commit. The
/// file write is a read-modify-write of the stored settings, never
/// a Keep snapshot of live, which would adopt a standing temporary
/// layout (#1179).
extension KiwiCore {
    /// What a tour paint reverts to: the settings live and in the
    /// live profile's file as they stood before the first paint.
    public struct ShelfPaintBaseline: Equatable, Sendable {
        let live: TilingSettings
        let profile: String?
        let stored: TilingSettings?
    }

    /// Records the settings a later `restoreShelf` returns to.
    public func shelfPaintBaseline() -> ShelfPaintBaseline {
        let name = profiles.currentName
        return ShelfPaintBaseline(
            live: tiler.settings,
            profile: name,
            stored: name.flatMap { try? profiles.read(name: $0).settings }
        )
    }

    /// Paints `look`'s styling and its palette, or — with no
    /// look — `palette`'s colours alone, keeping the shape.
    public func paintShelf(look: ShelfLook?, palette: ColorPalette?) {
        writeShelfSettings(profile: profiles.currentName) { settings in
            if let look {
                look.apply(to: &settings, palette: palette)
            } else {
                palette?.apply(to: &settings)
            }
        }
    }

    /// Puts back the settings `baseline` recorded, live and in the
    /// file it read — only while that profile is still the live one.
    public func restoreShelf(_ baseline: ShelfPaintBaseline) {
        let profile =
            baseline.profile == profiles.currentName
            ? baseline.profile : nil
        tiler.settings = baseline.live
        if let profile, let stored = baseline.stored {
            writeStoredSettings(profile) { $0 = stored }
        }
        redrawAfterPaint()
    }

    private func writeShelfSettings(
        profile: String?,
        _ paint: (inout TilingSettings) -> Void
    ) {
        paint(&tiler.settings)
        if let profile { writeStoredSettings(profile, paint) }
        redrawAfterPaint()
    }

    /// An explicit apply (§5): a look can move the shelf's edge.
    private func redrawAfterPaint() {
        retile(pass: .apply)
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
        } catch {
            onLog("tour look: profile \(name) not written: \(error)")
        }
    }
}
