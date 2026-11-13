import KiwiDeskCore
import SwiftUI

/// A `ComposedSymbol` drawn in SwiftUI (#3284): the base in the
/// ambient font and ink, cleared under the badge's corner, the badge
/// fitted flush into its square — all placed by Core's one
/// `ComposedSymbol.layout`, which `SymbolImage` draws in AppKit, so
/// the two never place it apart. SwiftUI cannot read the ambient
/// weight, so the badge takes `.bold` where AppKit steps it
/// `badgeWeightSteps` up.
struct ComposedSymbolView: View {
    let symbol: ComposedSymbol

    private var alignment: Alignment {
        symbol.corner == .bottomTrailing ? .bottomTrailing : .topTrailing
    }

    var body: some View {
        Image(systemName: symbol.base)
            .mask { GeometryReader { knockout(in: $0.size) } }
            .overlay { GeometryReader { badge(in: $0.size) } }
            .accessibilityHidden(true)
    }

    private func badge(in size: CGSize) -> some View {
        let square = symbol.layout(in: size, flipped: true).badge
        return Image(systemName: symbol.badge)
            .resizable()
            .fontWeight(.bold)
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
                    .offset(x: layout.knockout.minX, y: layout.knockout.minY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}
