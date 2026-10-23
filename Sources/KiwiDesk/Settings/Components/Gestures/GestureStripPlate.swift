import KiwiDeskCore
import SwiftUI

/// One picture in the shut card's strip: still, on its key frame —
/// a hover loop rebuilt each picture the page scrolled under the
/// pointer and stuttered the scroll (owner ruling 2026-10-18) —
/// its gesture's sentence as an AppKit tooltip (`PlateToolTip`),
/// half-faded where the gesture is off — faded, not `GreyOut`,
/// whose `.disabled` would refuse the click that lands on the
/// entry explaining why. Its click and hover cue are
/// `GestureStripHoverCue`'s (#2537).
struct GestureStripPlate: View {
    let item: GestureItem
    let settings: TilingSettings
    let gestures: ScrollGestureBase
    let onLand: (GestureItem) -> Void

    var body: some View {
        GesturePlate {
            item.picture(t: 1, gestures: gestures)
        }
        .opacity(item.isOff(gestures) ? 0.5 : 1)
        // Over the fade, so an off gesture's hover cue is as strong.
        .overlay(GestureStripHoverCue { onLand(item) })
        .overlay(PlateToolTip(text: item.sentence(settings)))
    }
}
