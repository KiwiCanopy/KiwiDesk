import KiwiDeskCore
import SwiftUI

/// A preview stroke's or fill's paint: Core's sheen ramp, top to
/// bottom over the shape, where the sheen draws (#1644), else the
/// flat colour. The ramp's colours and stops are the engine's
/// (#702), never a second derivation here.
enum SheenPaint {
    /// `sheen` is the signed strength; 0 is the flat colour.
    static func style(_ hex: String, sheen: CGFloat) -> AnyShapeStyle {
        guard sheen != 0 else {
            return AnyShapeStyle(Color(kiwiHex: hex))
        }
        let stops = zip(
            BorderSheen.colors(hex: hex, strength: sheen),
            BorderSheen.locations
        ).map { Gradient.Stop(color: Color(nsColor: $0), location: $1) }
        return AnyShapeStyle(
            LinearGradient(
                stops: stops,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
