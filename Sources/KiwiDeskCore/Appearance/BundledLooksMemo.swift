import CoreGraphics

/// The bundled looks last built, kept while the screens they were
/// sized for stay (#2993): a build reads two catalogs from disk, and
/// nothing else moves its answer (`LookCatalogSeamTests` ▸
/// `catalogReadsNoHost`). A failed read stays until the screens change.
struct BundledLooksMemo {
    /// How many times `build` ran, for tests.
    private(set) var builds = 0
    private var last: (sizes: [CGSize], looks: [ShelfLook])?

    /// The looks for `sizes`, built only when they differ from the
    /// last ones asked for.
    mutating func looks(
        for sizes: [CGSize],
        build: ([CGSize]) -> [ShelfLook]
    ) -> [ShelfLook] {
        if let last, last.sizes == sizes { return last.looks }
        let looks = build(sizes)
        builds += 1
        last = (sizes, looks)
        return looks
    }
}
