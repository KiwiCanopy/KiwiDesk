import KiwiDeskCore
import SwiftUI

/// A Space's glyph, in the system font, then its words (#1875):
/// the glyph is what matches the bar chip. Only a screen's name
/// shortens on a narrow row (#2792); the rest keeps its width.
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
            if let run = place.screen {
                HStack(spacing: 0) {
                    Text(run.lead).fixedSize()
                    Text(run.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(run.trail).fixedSize()
                }
            } else {
                Text(place.text).fixedSize()
            }
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
                        Text(literal).fixedSize().transition(.opacity)
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
