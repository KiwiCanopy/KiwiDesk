import Foundation

/// The speed preset (#3238): Settings' one pace control. Slow,
/// Default and Fast each write a fixed table of the six app-wide
/// lengths; Off is KiwiDesk's own Reduce Motion and leaves the
/// lengths alone, so leaving it restores the pace. Which segment
/// shows is derived, never stored: none matches is Custom.
public enum AnimationPacePreset: String, CaseIterable, Sendable {
    case off, slow, standard, fast

    /// The six lengths a speed writes, in ms.
    public struct Table: Equatable, Sendable {
        public let window, scroll, expand, reveal, slide, fade: Int
    }

    /// The owner's tables (#3238 ▸ Ruling, 2026-11-12): one ratio
    /// per speed, on the 50 ms step, inside each band.
    public var table: Table? {
        switch self {
        case .off: nil
        case .slow:
            Table(
                window: 250,
                scroll: 250,
                expand: 1250,
                reveal: 500,
                slide: 500,
                fade: 500
            )
        case .standard:
            Table(
                window: 150,
                scroll: 150,
                expand: 750,
                reveal: 300,
                slide: 300,
                fade: 300
            )
        case .fast:
            Table(
                window: 100,
                scroll: 100,
                expand: 500,
                reveal: 200,
                slide: 200,
                fade: 200
            )
        }
    }

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
