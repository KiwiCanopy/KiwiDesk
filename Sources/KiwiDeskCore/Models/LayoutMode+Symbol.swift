/// Each layout's SF Symbol — the one home the Layout menu, the
/// Settings tabs and the Space Bar's layout label share (#204,
/// #1535). `LayoutModeSymbolTests` resolves every case.
extension LayoutMode {
    public var symbol: String {
        switch self {
        case .bsp:
            return "square.split.bottomrightquarter"
        case .stack:
            return "rectangle.leadinghalf.inset.filled"
        case .scrolling:
            return "arrow.left.and.right.square"
        case .grid:
            return "square.grid.3x3"
        case .monocle:
            return "rectangle.inset.filled"
        case .track:
            return "rectangle.split.3x1"
        case .floating:
            return "rectangle.on.rectangle"
        }
    }
}
