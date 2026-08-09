import KiwiDeskCore
import SwiftUI

/// The two shared border decisions (#754): one width and one
/// corner shape across the focus ring, the drag ghost and the
/// drop zone.
///
/// The masters live here rather than in `BordersCard` because a
/// master is a WRITE FAN-OUT, not a layout concern: a binding
/// that sets one stored value beside a view is a place for a
/// second copy to disagree about which strokes the card owns.
/// The card renders these; nothing else writes the followers.
extension SettingsModel {
    /// The width every stroke takes. Writing it writes all
    /// three stored widths — there is no per-stroke width row
    /// in the GUI to disagree with it, and the per-stroke Lua
    /// verbs stay open and unclamped for anyone who wants three
    /// different ones.
    var borderWidthMaster: Binding<CGFloat> {
        Binding(
            get: { self.config.settings.borderStyle.width },
            set: { value in
                var next = self.config.settings
                next.borderStyle.width = value
                next.dragGhost.borderWidth = value
                next.dragDropZone.borderWidth = value
                self.config.settings = next
            }
        )
    }

    /// Square or Rounded, for all three strokes at once.
    ///
    /// The two halves are stored differently — the ring carries
    /// a two-value `cornerStyle`, the drag pair a 0–40 pt
    /// radius — so the master READS the radius and WRITES both.
    /// Reading the radius rather than the ring's own style is
    /// what lets a Lua-set 7 pt display as Rounded instead of
    /// as a picker with no segment selected, and the write is
    /// the only thing that ever normalises it: the getter never
    /// stores, so a radius the user did not open this card to
    /// change survives untouched. Picking a segment — including
    /// re-picking the one already shown — writes the pair, so a
    /// 7 pt radius becomes the system radius at that moment and
    /// not before.
    ///
    /// Rounded is the system window radius, which is also
    /// `dragCornerRadius`'s own default, so the shipped config
    /// already reads as Rounded without this ever writing.
    var borderCornersMaster: Binding<BorderStyle.CornerStyle> {
        Binding(
            get: {
                self.config.settings.dragCornerRadius > 0
                    ? .rounded : .square
            },
            set: { style in
                var next = self.config.settings
                next.borderStyle.cornerStyle = style
                next.dragCornerRadius =
                    style == .rounded
                    ? GeometryUtils.systemWindowCornerRadius : 0
                self.config.settings = next
            }
        )
    }
}
