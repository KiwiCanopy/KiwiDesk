import AppKit
import KiwiDeskCore
import SwiftUI

/// A `ComposedSymbol` drawn in SwiftUI (#3284): the base in the
/// ambient font and ink, cleared in a ring around the badge, the
/// badge fitted flush into its square — all placed by Core's one
/// `ComposedSymbol.layout`, whose canvas is the view's frame, as it
/// is the image `SymbolImage` draws in AppKit. SwiftUI cannot read
/// the ambient weight, so the badge takes the weight AppKit gives it
/// over a regular base; over a heavier base AppKit steps it further.
struct ComposedSymbolView: View {
    let symbol: ComposedSymbol

    /// The badge's weight over a regular base, from Core's ladder.
    static let badgeWeight = Font.Weight(SymbolImage.Style().badge.weight)

    private var alignment: Alignment {
        symbol.corner == .bottomTrailing ? .bottomTrailing : .topTrailing
    }

    var body: some View {
        CanvasFrame(symbol: symbol) {
            Image(systemName: symbol.base)
                .mask { GeometryReader { knockout(in: $0.size) } }
                .overlay { GeometryReader { badge(in: $0.size) } }
        }
        .accessibilityHidden(true)
    }

    private func badge(in size: CGSize) -> some View {
        let square = symbol.layout(in: size, flipped: true).badge
        return Image(systemName: symbol.badge)
            .resizable()
            .fontWeight(Self.badgeWeight)
            .aspectRatio(contentMode: .fit)
            .frame(
                width: square.width,
                height: square.height,
                alignment: alignment
            )
            .offset(x: square.minX, y: square.minY)
    }

    /// Opaque everywhere but the layout's cleared area.
    private func knockout(in size: CGSize) -> some View {
        let layout = symbol.layout(in: size, flipped: true)
        return Rectangle()
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: layout.radius)
                    .frame(
                        width: layout.knockout.width,
                        height: layout.knockout.height
                    )
                    .offset(
                        x: layout.knockout.minX,
                        y: layout.knockout.minY
                    )
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}

/// Sizes its one child, the base, to the layout's canvas and places
/// it where the canvas puts it, so the badge's overhang is inside
/// the frame.
private struct CanvasFrame: Layout {
    let symbol: ComposedSymbol

    private func canvas(of base: CGSize) -> CGRect {
        symbol.layout(in: base, flipped: true).canvas
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let base = subviews.first?.sizeThatFits(.unspecified)
        else { return .zero }
        return canvas(of: base).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let child = subviews.first else { return }
        let base = child.sizeThatFits(.unspecified)
        let canvas = canvas(of: base)
        child.place(
            at: CGPoint(
                x: bounds.minX - canvas.minX,
                y: bounds.minY - canvas.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(base)
        )
    }
}

extension Font.Weight {
    /// The SwiftUI weight of an AppKit one, nearest below.
    fileprivate init(_ weight: NSFont.Weight) {
        let ladder: [(NSFont.Weight, Font.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light),
            (.regular, .regular), (.medium, .medium),
            (.semibold, .semibold), (.bold, .bold), (.heavy, .heavy),
            (.black, .black),
        ]
        self =
            ladder.last { $0.0.rawValue <= weight.rawValue }?.1 ?? .regular
    }
}
