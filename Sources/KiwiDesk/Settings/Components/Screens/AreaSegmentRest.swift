import KiwiDeskCore
import SwiftUI

/// While one segment of a joined divider moves (#3611), the rest of
/// its line stays drawn where it was, unlit and out of the hit test.
struct AreaSegmentRest: View {
    /// The dragged divider as stored.
    let stored: ScreenAreaCut
    /// The piece of it in flight.
    let segment: ScreenAreaCut
    /// Card points per screen point along each axis.
    let scale: CGSize

    var body: some View {
        let side = stored.axis == .sideBySide
        let along = side ? scale.width : scale.height
        let across = side ? scale.height : scale.width
        let at = CGFloat(stored.position) * along
        ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
            let from = CGFloat(piece.start) * across
            let span = CGFloat(piece.end - piece.start) * across
            Rectangle()
                .fill(SettingsTheme.hairline)
                .frame(width: side ? 1 : span, height: side ? span : 1)
                .offset(
                    x: side ? at - 0.5 : from,
                    y: side ? from : at - 0.5
                )
                .allowsHitTesting(false)
        }
    }

    /// The spans of the line on either side of the segment.
    private var pieces: [(start: Int, end: Int)] {
        [(stored.start, segment.start), (segment.end, stored.end)]
            .filter { $0.0 < $0.1 }
    }
}
