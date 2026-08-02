import SwiftUI

/// The 2-column swatch grid the colour runs share (#2): every
/// group on the Advanced Colours page wraps its `HexColorField`s
/// in this, so four grids over four different subsystems read as
/// one page. Flexible columns, so the grids span the pane's full
/// width identically; a row's own label width sets where the
/// swatch sits inside its (equal-width) cell.
///
/// Grouping swatches by type rather than by topic is the one
/// carve-out `gui.md` grants — a colour gates nothing, so nothing
/// is separated from what it controls.
struct ColorGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ],
            alignment: .leading,
            spacing: 8
        ) {
            content
        }
    }
}
