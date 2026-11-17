import AppKit
import SwiftUI

/// A gesture's glyph by the name `ShortcutGestureBadge.symbol`
/// resolves: a drawn `CustomGlyph` where one exists, else an SF
/// Symbol. The shortcuts panel and the tour draw through it (#3427).
struct GestureGlyph: View {
    let symbol: String
    let side: CGFloat

    var body: some View {
        Group {
            if let custom = CustomGlyph(name: symbol) {
                Image(nsImage: custom.image)
                    .renderingMode(.template)
                    .resizable()
            } else {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: side, height: side)
    }
}
