import KiwiDeskCore
import SwiftUI

/// Maps a bar's absolute edge plus its along-axis alignment
/// onto the composite SwiftUI `Alignment` a preview canvas
/// uses (#293 QA): the edge supplies the cross-axis component
/// (the strip hugs its matching side; the off-axis emptiness
/// mirrors the bar's real relationship to the desktop), the
/// alignment the along-axis one. Both preview strips share
/// this one mapping. GUI-side on purpose — SwiftUI's
/// `Alignment` must never leak into KiwiDeskCore.
extension AppBarEdge {
    func canvasAlignment(
        _ alignment: AppBarStyle.BarAlignment
    ) -> Alignment {
        let along: (HorizontalAlignment, VerticalAlignment)
        switch alignment {
        case .start: along = (.leading, .top)
        case .center: along = (.center, .center)
        case .end: along = (.trailing, .bottom)
        }
        switch self {
        case .top:
            return Alignment(
                horizontal: along.0,
                vertical: .top
            )
        case .bottom:
            return Alignment(
                horizontal: along.0,
                vertical: .bottom
            )
        case .left:
            return Alignment(
                horizontal: .leading,
                vertical: along.1
            )
        case .right:
            return Alignment(
                horizontal: .trailing,
                vertical: along.1
            )
        }
    }
}
