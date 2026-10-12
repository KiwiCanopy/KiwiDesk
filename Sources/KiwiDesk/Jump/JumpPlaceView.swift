import KiwiDeskCore
import SwiftUI

/// A Space's glyph, in the system font, then its words (#1875):
/// the glyph is what matches the bar chip.
struct JumpPlaceView: View {
    let place: JumpRowText.Place

    var body: some View {
        HStack(spacing: 4) {
            switch place.glyph {
            case .symbol(let name):
                Image(systemName: name)
                    .accessibilityHidden(true)
            case .text(let text, _):
                Text(text)
                    .accessibilityHidden(true)
            case nil:
                EmptyView()
            }
            Text(place.text)
        }
    }
}

/// The column of a row Move here can bring: where the window is,
/// and — on the selected row while ⇧ is held — the way to the
/// current Space, in the frame's own order. The source stays one
/// view, so the way here grows beside it rather than replacing
/// it. The frame's literals carry the spacing.
struct JumpWayHereView: View {
    let source: JumpRowText.Place?
    let here: JumpRowText.Place
    let expanded: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(
                SentenceFrame(JumpRowText.wayHereFrame).segments
            ) { segment in
                switch segment.slot {
                case .argument(1):
                    if let source { JumpPlaceView(place: source) }
                case .text(let literal):
                    if expanded {
                        Text(literal).transition(.opacity)
                    }
                case .argument(2):
                    if expanded {
                        JumpPlaceView(place: here)
                            .transition(.opacity)
                    }
                case .argument:
                    EmptyView()
                }
            }
        }
    }
}
