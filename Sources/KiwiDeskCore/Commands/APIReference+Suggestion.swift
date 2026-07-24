import Foundation

/// Did-you-mean suggestion for an unknown command, split from
/// `APIReference.swift` for the 350-line file ceiling.
extension APIReference {
    /// A close known command for a typo, if any. Suggests only
    /// dispatchable names — the unknown-command path is reached
    /// from the CLI/IPC socket too, where a Lua-only name would
    /// be a dead-end hint.
    public static func suggestion(
        for unknown: String
    ) -> String? {
        var best: (name: String, distance: Int)?
        for name in dispatchable {
            let distance = editDistance(unknown, name)
            let limit = max(2, unknown.count / 3)
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
