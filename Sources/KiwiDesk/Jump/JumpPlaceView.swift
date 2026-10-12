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

/// The selected row's column while ⇧ is held: where the window
/// is, then the current Space, in the frame's own order. The
/// frame's literals carry the spacing, so the stack adds none.
struct JumpWayHereView: View {
    let source: JumpRowText.Place?
    let here: JumpRowText.Place

    var body: some View {
        HStack(spacing: 0) {
            ForEach(
                SentenceFrame(JumpRowText.wayHereFrame).segments
            ) { segment in
                switch segment.slot {
                case .text(let literal):
                    Text(literal)
                case .argument(1):
                    if let source { JumpPlaceView(place: source) }
                case .argument(2):
                    JumpPlaceView(place: here)
                case .argument:
                    EmptyView()
                }
            }
        }
    }
}
