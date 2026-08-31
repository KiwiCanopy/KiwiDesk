import Foundation

/// Command typo suggestion provider for APIReference.
extension APIReference {
    /// Returns closest dispatchable command suggestion for typo, if any.
    public static func suggestion(
        for unknown: String
    ) -> String? {
        closest(to: unknown, among: dispatchable)
    }

    /// Finds nearest candidate within edit distance limit (#1033).
    static func closest<C: Sequence<String>>(
        to unknown: String,
        among candidates: C
    ) -> String? {
        let limit = max(2, unknown.count / 3)
        var best: (name: String, distance: Int)?
        for name in candidates {
            let distance = editDistance(unknown, name)
            guard distance <= limit else { continue }
            if best == nil || distance < best!.distance {
                best = (name, distance)
            }
        }
        return best?.name
    }

    /// Levenshtein distance (small inputs only).
    static func editDistance(
        _ a: String,
        _ b: String
    ) -> Int {
        let left = Array(a)
        let right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        var current = [Int](
            repeating: 0,
            count: right.count + 1
        )
        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = Swift.min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}
