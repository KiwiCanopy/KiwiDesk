import Foundation

extension Navigation {
    /// The next index along a flat row from `index` by `step` (±1),
    /// past every index `skip` refuses, wrapping past an end where
    /// `wrap` allows (#168); a lens's focus keys skip other apps'
    /// windows this way (#2103 ruling 30). Nil where no index is
    /// left — the origin never.
    public static func arrayStep(
        from index: Int,
        step: Int,
        count: Int,
        wrap: Bool,
        skip: (Int) -> Bool = { _ in false }
    ) -> Int? {
        var next = index
        for _ in 0..<count {
            next += step
            if !(0..<count).contains(next) {
                guard wrap else { return nil }
                next = step > 0 ? 0 : count - 1
            }
            if next == index { return nil }
            if !skip(next) { return next }
        }
        return nil
    }
}
