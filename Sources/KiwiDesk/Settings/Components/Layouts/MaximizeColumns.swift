import SwiftUI

/// The Maximize card's column widths (#3255): each column is as wide
/// as its widest drawn cell, never under `floor`, and its heading
/// takes the same width. A menu pop-up draws at its
/// widest item whatever frame it gets, so a fixed column let a
/// translated "Custom…" run under the next column.
struct MaximizeColumns: Equatable {
    /// A column's narrowest width, in points.
    static let floor: CGFloat = 120
    /// Each column's widest drawn cell, by census id.
    var drawn: [String: CGFloat] = [:]

    /// `key`'s column width in points.
    func width(of key: SettingKey) -> CGFloat {
        max(Self.floor, drawn[key.id] ?? 0)
    }

    /// The cells' own widths, read before their column's frame.
    struct Drawn: PreferenceKey {
        static let defaultValue: [String: CGFloat] = [:]

        static func reduce(
            value: inout [String: CGFloat],
            nextValue: () -> [String: CGFloat]
        ) {
            value.merge(nextValue(), uniquingKeysWith: max)
        }
    }
}

extension View {
    /// Reports this cell's own width as `key`'s column.
    func measuredColumn(_ key: SettingKey) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MaximizeColumns.Drawn.self,
                    value: [key.id: proxy.size.width]
                )
            }
        }
    }
}
