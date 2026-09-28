import KiwiDeskCore

extension TilingSettings {
    /// Both bars on one edge — the fused shelf a fixture written
    /// before #1731 meant by `kiwishelf.edge`.
    var barEdge: AppBarEdge {
        get { spaceBarStyle.edge }
        set {
            spaceBarStyle.edge = newValue
            appBarStyle.edge = newValue
        }
    }
}
