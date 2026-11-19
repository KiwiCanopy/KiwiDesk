import CoreGraphics

/// Where a screen sits among the screens sharing its name, so two
/// identical screens can be told apart in words (#2756 ▸ the
/// preview questions, 6). Core names the position; the GUI words
/// it.
public enum ScreenNamePosition: Sendable, Equatable {
    case left, middle, right, above, below
}

extension ScreenShiftPlan {
    /// One string per arrangement: every screen's identity, origin
    /// and size. The offer's answer is remembered against it, so a
    /// changed arrangement asks again.
    public static func arrangementKey(
        _ screens: [ArrangedScreen]
    ) -> String {
        screens.map {
            let f = $0.frame
            return "\($0.id)@\(Int(f.minX)),\(Int(f.minY)),"
                + "\(Int(f.width))x\(Int(f.height))"
        }
        .sorted()
        .joined(separator: ";")
    }

    /// The position of each screen whose name another screen
    /// shares, macOS's " (n)" numbering dropped
    /// (`ScreenLabel.baseName`); a uniquely named screen has none.
    /// Side by side reads left to right, stacked reads above and
    /// below. Frames are y-down, as `ArrangedScreen`'s are.
    public static func namePositions<Key: Hashable>(
        _ screens: [(key: Key, name: String, frame: CGRect)]
    ) -> [Key: ScreenNamePosition] {
        var found: [Key: ScreenNamePosition] = [:]
        let groups = Dictionary(grouping: screens) {
            ScreenLabel.baseName($0.name)
        }
        for group in groups.values where group.count > 1 {
            let xs = group.map(\.frame.midX)
            let ys = group.map(\.frame.midY)
            let wide =
                (xs.max()! - xs.min()!) >= (ys.max()! - ys.min()!)
            let ordered = group.sorted {
                wide
                    ? $0.frame.midX < $1.frame.midX
                    : $0.frame.midY < $1.frame.midY
            }
            for (index, screen) in ordered.enumerated() {
                let first = index == 0
                let last = index == ordered.count - 1
                found[screen.key] =
                    wide
                    ? (first ? .left : last ? .right : .middle)
                    : (first ? .above : last ? .below : .middle)
            }
        }
        return found
    }
}
