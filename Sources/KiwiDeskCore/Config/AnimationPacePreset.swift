import Foundation

/// The speed preset (#3238, #3254): Settings' one pace control.
/// Very Slow, Slow, Medium and Fast each write a fixed table of the
/// six app-wide lengths; Off is KiwiDesk's own Reduce Motion and
/// leaves the lengths alone, so leaving it restores the pace. Which
/// segment shows is derived, never stored: none matches is Custom.
public enum AnimationPacePreset: String, CaseIterable, Sendable {
    case off, verySlow, slow, medium, fast

    /// The six lengths a speed writes, in ms.
    public struct Table: Equatable, Sendable {
        public let window, scroll, expand, reveal, slide, fade: Int
    }

    /// The owner's tables (#3254 ▸ Ruling, 2026-11-12): 100 ms a step
    /// on the window, reveal, slide and fade at twice it, expand at
    /// five times, each inside its band. Medium is the shipped pace.
    public var table: Table? {
        switch self {
        case .off: nil
        case .verySlow: Self.table(window: 400)
        case .slow: Self.table(window: 300)
        case .medium: Self.shipped
        case .fast: Self.table(window: 100)
        }
    }

    /// Medium's table: the shipped lengths, which the app-wide
    /// defaults and the window engine's stored ones read. Retuning it
    /// moves six stored defaults and owes profiles.md's crossing
    /// question (#1369, #1359).
    public static let shipped = table(window: 200)

    private static func table(window: Int) -> Table {
        Table(
            window: window,
            scroll: window,
            expand: window * 5,
            reveal: window * 2,
            slide: window * 2,
            fade: window * 2
        )
    }

    /// 4.2's shipped lengths, spelled as history: an install still
    /// on all six moves to Medium at #3237's crossing (#3254 ▸
    /// Ruling amendment).
    public static let legacyDefaults = Table(
        window: 150,
        scroll: 150,
        expand: 750,
        reveal: 300,
        slide: 300,
        fade: 300
    )

    /// The segment `pace` shows: Off while KiwiDesk's own Reduce
    /// Motion holds, else the speed whose table it matches, nil for
    /// Custom.
    public static func current(of pace: AppWideSettings) -> Self? {
        if pace.animationReduceMotion { return .off }
        let lengths = pace.paceTable
        return allCases.first { $0.table == lengths }
    }
}

extension AppWideSettings {
    /// The six lengths as a preset's table reads them.
    public var paceTable: AnimationPacePreset.Table {
        AnimationPacePreset.Table(
            window: animationDurationMS,
            scroll: animationScrollDurationMS,
            expand: animationExpandDurationMS,
            reveal: animationRevealDurationMS,
            slide: spaceSlideDuration,
            fade: visionFadeDuration
        )
    }

    /// `preset` written: Off turns KiwiDesk's Reduce Motion on and
    /// keeps the lengths; a speed turns it off and writes its table.
    public mutating func applyPace(_ preset: AnimationPacePreset) {
        guard let table = preset.table else {
            animationReduceMotion = true
            return
        }
        animationReduceMotion = false
        animationDurationMS = table.window
        animationScrollDurationMS = table.scroll
        animationExpandDurationMS = table.expand
        animationRevealDurationMS = table.reveal
        spaceSlideDuration = table.slide
        visionFadeDuration = table.fade
    }
}
