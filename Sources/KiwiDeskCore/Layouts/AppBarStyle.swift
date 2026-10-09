import CoreGraphics
import Foundation

/// The App Bar's own look and behavior (monocle, scrolling).
/// The look both bars share is `KiwiShelf`'s (#1517); a drawing
/// reads `AppBarLook`. An item draws its icon and title, and on a
/// vertical edge its icon alone — rendering, not a setting (#1528).
public struct AppBarStyle: Sendable, Equatable {
    /// The screen edge the bar sits on (top) — global only, never
    /// a layout's override (`layoutFixedKeys`). The Space Bar on
    /// the same edge shares one shelf with it (#1731).
    public var edge: AppBarEdge = .top
    /// A screen's own edge, keyed by its fingerprint (#1948); a
    /// screen with none uses `edge`. Global only, like `edge`.
    public var edgeOverride: [String: AppBarEdge] = [:]
    /// Edge mark by default, where the Space Bar's is Outline:
    /// the indicator's SHAPE is what tells the sections apart
    /// (#1517).
    public var activeIndicator: ActiveIndicator = .edgeMark
    /// Longest title drawn per item before tail-truncation (#1171).
    public var titleCap = 10
    /// Group adjacent windows of the same app with a count badge.
    public var groupAdjacentWindows = true
    /// Whether the layout gives up the bar's strip (#1524); off
    /// draws the bar over the windows. Global only, like `edge`.
    public var reserve = true

    public init() {}

    /// Fields no layout may override, each with the global verb
    /// that writes it — the one value the layouts' refusal and
    /// the retired per-layout edge verbs name. An edge per layout
    /// would carry the bar across the screen on a layout switch,
    /// so `LayoutAppBar` mirrors every field but these (#1731);
    /// the reservation is the bar's, never a layout's (#1524),
    /// and a screen's edge is written by `set_edge` (#1948).
    static let layoutFixedKeys: [CodingKeys: String] = {
        let keys: [CodingKeys] = [.edge, .edgeOverride, .reserve]
        return Dictionary(
            uniqueKeysWithValues: keys.map { key in
                let field = BarStyleKeys.setterField(
                    of: key.stringValue
                )
                return (key, "app_bar.set_\(field)")
            }
        )
    }()

    /// Clamps dim factor to valid range [0.05, 1.0].
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }
}

extension AppBarStyle: Codable, ScreenEdged {
}
