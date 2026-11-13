import KiwiDeskCore
import SwiftUI

/// A `ComposedSymbol` drawn in SwiftUI (#3284): the base in the
/// ambient font and ink, the base cleared under a circle around the
/// badge, the badge scaled into its corner — so it sizes and tints
/// as a symbol does. Core's `SymbolImage` draws the same table in
/// AppKit.
struct ComposedSymbolView: View {
    let symbol: ComposedSymbol

    private var alignment: Alignment {
        symbol.corner == .bottomTrailing ? .bottomTrailing : .topTrailing
    }

    private var anchor: UnitPoint {
        symbol.corner == .bottomTrailing ? .bottomTrailing : .topTrailing
    }

    var body: some View {
        Image(systemName: symbol.base)
            .mask { knockout }
            .overlay(alignment: alignment) { badge }
            .accessibilityHidden(true)
    }

    private var badge: some View {
        Image(systemName: symbol.badge)
            .scaleEffect(ComposedSymbol.badgeShare, anchor: anchor)
    }

    /// Opaque everywhere but a circle around the badge.
    private var knockout: some View {
        Rectangle()
            .overlay(alignment: alignment) {
                Image(systemName: symbol.badge)
                    .hidden()
                    .background(Circle().scale(ComposedSymbol.haloShare))
                    .scaleEffect(ComposedSymbol.badgeShare, anchor: anchor)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}
