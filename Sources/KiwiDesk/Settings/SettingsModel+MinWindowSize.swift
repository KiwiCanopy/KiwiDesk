import KiwiDeskCore
import SwiftUI

/// One axis of a minimum window size (#2237).
enum MinSizeAxis: CaseIterable, Hashable {
    case width
    case height
}

extension MinSize {
    subscript(axis: MinSizeAxis) -> CGFloat {
        get { axis == .width ? width : height }
        set {
            if axis == .width { width = newValue } else { height = newValue }
        }
    }
}

/// The minimum window size master and its per-layout rows (#2237).
/// The master is the third acknowledging home (gui.md ▸ A master
/// whose followers disagree): it answers its `?` and its "Mixed"
/// readout from `minSizeShared(_:)` alone, never a census gate.
extension SettingsModel {
    private var minSizes: MinWindowSizes {
        config.settings.minWindowSizes
    }

    /// Every layout's value on `axis`, nil while they differ — the
    /// master's readout.
    func minSizeShared(_ axis: MinSizeAxis) -> Int? {
        let values = Set(
            MinWindowSizes.Layout.allCases.map { Int(minSizes[$0][axis]) }
        )
        return values.count == 1 ? values.first : nil
    }

    /// Whether any axis reads "Mixed": the master's `?` and the
    /// drawer's hold-open both read this.
    var minSizesDiffer: Bool {
        MinSizeAxis.allCases.contains { minSizeShared($0) == nil }
    }

    /// The value the master steps from and a row is compared to on
    /// `axis`: the value most layouts share, a tie going to the
    /// profile's most-used layout.
    func minSizeReference(_ axis: MinSizeAxis) -> Int {
        let layouts = MinWindowSizes.Layout.allCases
        var counts: [Int: Int] = [:]
        for layout in layouts {
            counts[Int(minSizes[layout][axis]), default: 0] += 1
        }
        let top = counts.values.max() ?? 0
        let used =
            MinWindowSizes.Layout(LayoutUsage.mostUsed(in: config))
            ?? .bsp
        let preferred = Int(minSizes[used][axis])
        if counts[preferred] == top { return preferred }
        return counts.filter { $0.value == top }.keys.min() ?? preferred
    }

    /// Whether `layout` differs from the others on either axis —
    /// the row's accent.
    func minSizeStandsApart(_ layout: MinWindowSizes.Layout) -> Bool {
        MinSizeAxis.allCases.contains {
            Int(minSizes[layout][$0]) != minSizeReference($0)
        }
    }

    /// Sets `axis` to `value` for `layout`, or for every layout
    /// where nil — the master's write.
    func setMinSize(
        _ value: Int,
        axis: MinSizeAxis,
        for layout: MinWindowSizes.Layout?
    ) {
        let layouts = layout.map { [$0] } ?? MinWindowSizes.Layout.allCases
        for one in layouts {
            config.settings.minWindowSizes[one][axis] = CGFloat(value)
        }
    }

    /// The value `layout` uses on `axis`.
    func minSize(
        _ layout: MinWindowSizes.Layout,
        _ axis: MinSizeAxis
    ) -> Int {
        Int(minSizes[layout][axis])
    }
}
