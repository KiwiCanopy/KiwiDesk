import Foundation

/// A screen as a label names it (#2792): its own name, and its
/// place where another connected screen shares that name — its
/// index in `PositionalDisplays.ordered` — which the GUI narrates
/// as "Main screen" / "Screen 2" (#96).
public struct ScreenLabel: Sendable, Equatable {
    public let name: String
    /// Nil while the name is unique among the connected screens.
    public let twinPlace: Int?

    public init(name: String, twinPlace: Int? = nil) {
        self.name = name
        self.twinPlace = twinPlace
    }

    /// `name` without the " (n)" macOS appends to identical
    /// screens' `localizedName`: the name twins are grouped and
    /// labelled by (#3351). A lone screen keeps its whole name,
    /// since callers strip only within a group of two or more.
    public static func baseName(_ name: String) -> String {
        guard name.hasSuffix(")"),
            let open = name.range(of: " (", options: .backwards)
        else { return name }
        let digits = name[open.upperBound...].dropLast()
        guard !digits.isEmpty,
            digits.allSatisfy({ $0.isASCII && $0.isNumber })
        else { return name }
        return String(name[..<open.lowerBound])
    }
}
