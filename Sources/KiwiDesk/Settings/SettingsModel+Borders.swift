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
///
/// Which stored leaves each one writes is also declared as
/// DATA, in `SettingKey.masterWrites`, because the
/// unsaved-changes count has to attribute those leaves to one
/// row. That is a second copy of the same fact, so
/// `BorderMastersFanOutTests` writes each master and compares
/// the leaves that actually moved against the declaration.
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

    /// Square or Rounded, for all three strokes at once — or
    /// NOTHING selected, while the two stored halves disagree.
    ///
    /// The halves are stored differently: the ring carries a
    /// two-value `cornerStyle`, the drag pair a 0–40 pt radius.
    /// A Lua call can move one without the other, and the
    /// picker then sits directly above a ring preview drawing
    /// the answer it does not show. So the selection is
    /// OPTIONAL and `GapsBordersGates.agreedCornerStyle` is the
    /// one predicate that resolves it: nil when the halves
    /// disagree, which `SegmentedPicker` renders as no segment
    /// selected. Making the preview read this master instead
    /// was the alternative and is worse — the preview would
    /// then stop showing what the app draws.
    ///
    /// **The getter never stores, and a pick is idempotent.**
    /// A 7 pt radius under a rounded ring reads as Rounded and
    /// STAYS 7 pt, re-picking Rounded included: Rounded writes
    /// the system radius only where there is no rounding to
    /// keep. Re-affirming a segment must change nothing, or the
    /// "opening this page rewrites nothing" promise lasts only
    /// until a stray tap — which is likelier than a deliberate
    /// one. Square is the one shape with a single radius, so it
    /// writes 0 outright.
    var borderCornersMaster: Binding<BorderStyle.CornerStyle?> {
        Binding(
            get: {
                GapsBordersGates(
                    settings: self.config.settings
                ).agreedCornerStyle
            },
            set: { style in
                guard let style else { return }
                var next = self.config.settings
                next.borderStyle.cornerStyle = style
                if style == .square {
                    next.dragCornerRadius = 0
                } else if next.dragCornerRadius <= 0 {
                    next.dragCornerRadius =
                        GeometryUtils.systemWindowCornerRadius
                }
                self.config.settings = next
            }
        )
    }
}
