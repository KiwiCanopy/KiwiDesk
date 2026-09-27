import KiwiDeskCore
import SwiftUI

/// A preview stroke's or fill's paint: Core's sheen ramp, top to
/// bottom over the shape, where the sheen draws (#1644), else the
/// flat colour. The ramp's colours and stops are the engine's
/// (#702), never a second derivation here; `plate` is the bar Fill
/// a bar surface's contrast is capped against, as the live bar's.
enum SheenPaint {
    static func style(
        _ hex: String,
        sheen: Bool,
        plate: String? = nil
    ) -> AnyShapeStyle {
        guard sheen else { return AnyShapeStyle(Color(kiwiHex: hex)) }
        let grounds =
            plate.map { BorderSheen.grounds(plate: $0) }
            ?? BorderSheen.wallpapers
        let stops = zip(
            BorderSheen.colors(hex: hex, over: grounds),
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
