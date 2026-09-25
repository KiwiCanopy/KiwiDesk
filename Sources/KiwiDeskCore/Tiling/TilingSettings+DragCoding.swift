import CoreGraphics
import Foundation

/// The `drag` group's decode, split from `TilingSettings+Coding`
/// at the file ceiling.
extension TilingSettings {
    /// Reads `drag.*`: the corner radius, the Liquid Glass leaf
    /// (#1620) and the two visuals, each over its own defaults.
    mutating func decodeDrag(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        guard container.contains(.drag) else { return }
        let drag = try container.nestedContainer(
            keyedBy: DragKeys.self,
            forKey: .drag
        )
        dragCornerRadius =
            try drag.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRadius
            ) ?? 16
        dragLiquidGlass =
            try drag.decodeIfPresent(
                Bool.self,
                forKey: .liquidGlass
            ) ?? TilingSettings().dragLiquidGlass
        if drag.contains(.ghost) {
            dragGhost = try DragVisual(
                from: drag.superDecoder(forKey: .ghost),
                defaults: .ghostDefault
            )
        }
        if drag.contains(.dropZone) {
            dragDropZone = try DragVisual(
                from: drag.superDecoder(forKey: .dropZone),
                defaults: .dropZoneDefault
            )
        }
    }
}
