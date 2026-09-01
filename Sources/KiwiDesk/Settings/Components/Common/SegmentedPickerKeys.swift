import Foundation

/// The arrow-key arithmetic, lifted out of the view so it can be
/// read without a host (`SegmentedPickerKeyTests`, #997).
enum SegmentedPickerKeys {
    /// Index an arrow press lands on, or nil when there is
    /// nothing to land on. Clamped, never wrapping — a native
    /// segmented control stops at its ends — and an UNMATCHED
    /// selection (nil, #754) lands on the first option rather
    /// than stepping from an index it does not have.
    static func step(
        from current: Int?,
        by direction: Int,
        count: Int
    ) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return 0 }
        return min(max(current + direction, 0), count - 1)
    }
}
