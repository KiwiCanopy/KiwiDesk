import KiwiDeskCore
import SwiftUI

/// Maps bar edge and along-axis alignment to SwiftUI `Alignment` (#293).
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
