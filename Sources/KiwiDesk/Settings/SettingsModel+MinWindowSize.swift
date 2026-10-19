import KiwiDeskCore
import SwiftUI

/// The minimum window size master and its per-layout rows (#2237).
/// The master is a ruled acknowledging home (gui.md ▸ A master
/// whose followers disagree): it answers its `?` and its "Mixed"
/// readout from `minSizeShared(_:)` alone, never a census gate.
extension SettingsModel {
    private var minSizes: MinWindowSizes {
        config.settings.minWindowSizes
    }

    /// Every layout's value on `axis`, nil while they differ — the
    /// master's readout.
    func minSizeShared(_ axis: MinSizeAxis) -> Int? {
        minSizes.shared(axis).map { Int($0) }
    }

    /// Whether any axis reads "Mixed": the master's `?` and the
    /// drawer's hold-open both read this.
    var minSizesDiffer: Bool {
        MinSizeAxis.allCases.contains { minSizeShared($0) == nil }
    }

    /// The value the master steps from on a mixed `axis`, and a
    /// row is compared to: the profile's most-used layout's.
    func minSizeReference(_ axis: MinSizeAxis) -> Int {
        Int(minSizes[minSizeMostUsed][axis])
    }

    /// The profile's most-used layout among those keeping a floor,
    /// BSP where no Space uses one — Monocle has none to step from.
    var minSizeMostUsed: MinWindowSizes.Layout {
        let counts = MinWindowSizes.Layout.allCases.map {
            ($0, LayoutUsage.spaces(on: $0.mode, in: config).count)
        }
        return counts.max { $0.1 < $1.1 }
            .flatMap { $0.1 > 0 ? $0.0 : nil } ?? .bsp
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
