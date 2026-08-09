import KiwiDeskCore
import SwiftUI

/// The two shared border decisions (#754): one width across the
/// focus ring, the drag ghost and the drop zone, and one corner
/// radius the ring's corner style derives from.
///
/// The masters live here rather than in `BordersCard` because a
/// master is a WRITE FAN-OUT, not a layout concern: a binding
/// that sets one stored value beside a view is a place for a
/// second copy to disagree about which strokes are linked. The
/// card renders these; nothing else writes the followers.
extension SettingsModel {
    /// Persists the link and, on turning it ON, makes the claim
    /// true immediately: the followers are synced right then
    /// rather than at the next master edit, so a user who links
    /// and saves gets the one look the toggle promised.
    /// (Turning it OFF changes no value — the three widths
    /// simply become independent again.)
    ///
    /// One residue, stated rather than chased: a draft loaded
    /// from a profile that Lua gave three different widths
    /// arrives un-synced, and its greyed sliders read those
    /// stored values until a master is touched. Re-deriving on
    /// every load is the alternative and is worse — it would
    /// rewrite a saved profile the user never opened this card
    /// to change.
    func setBorderWidthLinked(_ linked: Bool) {
        BorderWidthLinkPreference.write(linked, to: preferences)
        borderWidthLinked = linked
        if linked { config.settings = linkedShape(config.settings) }
    }

    /// The master width: the focus ring's own stored value, and
    /// — while linked — the ghost's and the drop zone's too.
    var borderWidthMaster: Binding<CGFloat> {
        Binding(
            get: { self.config.settings.borderStyle.width },
            set: { value in
                var next = self.config.settings
                next.borderStyle.width = value
                self.config.settings =
                    self.borderWidthLinked
                    ? self.linkedShape(next) : next
            }
        )
    }

    /// The master corner radius: the drag pair's own shared
    /// value, and — while linked — the source the ring's
    /// Rounded/Square choice derives from.
    var borderCornerMaster: Binding<CGFloat> {
        Binding(
            get: { self.config.settings.dragCornerRadius },
            set: { value in
                var next = self.config.settings
                next.dragCornerRadius = value
                self.config.settings =
                    self.borderWidthLinked
                    ? self.linkedShape(next) : next
            }
        )
    }

    /// The followers, derived from the two masters. Corner is a
    /// derivation rather than a copy because the ring has no
    /// radius: a zero radius is a square frame, anything above
    /// it a rounded one, which is the whole of what the ring's
    /// two-value picker can say.
    private func linkedShape(
        _ settings: TilingSettings
    ) -> TilingSettings {
        var next = settings
        next.dragGhost.borderWidth = next.borderStyle.width
        next.dragDropZone.borderWidth = next.borderStyle.width
        next.borderStyle.cornerStyle =
            next.dragCornerRadius > 0 ? .rounded : .square
        return next
    }
}
