import CoreGraphics
import Foundation

/// The settings a preset set on purpose (#1663): sparse, like a
/// profile's overrides — an absent leaf is the screen's shape
/// tuning. A leaf joins when a preset needs one.
public struct PresetTuning: Sendable, Equatable {
    /// Uniform gap in points.
    public var gap: Double?
    public var scrollingAnchor: ScrollingParams.Anchor?

    public init(
        gap: Double? = nil,
        scrollingAnchor: ScrollingParams.Anchor? = nil
    ) {
        self.gap = gap
        self.scrollingAnchor = scrollingAnchor
    }

    /// Lays the declared leaves over `settings`.
    func apply(to settings: inout TilingSettings) {
        if let gap { settings.gapsGlobal = .uniform(gap) }
        if let scrollingAnchor {
            settings.scrolling.anchor = scrollingAnchor
        }
    }
}

extension StandardLayout {
    /// Where a layout's settings come from.
    enum Tuning: Sendable, Equatable {
        /// Already derived for its screens: the starter.
        case resolved(TilingSettings)
        /// Laid over the shape tuning of the screens it lands on.
        case preset(PresetTuning)
    }

    /// The settings this layout takes on `sizes`, in positional
    /// order — THE one merge of shape tuning and a preset's own
    /// leaves (#1663, `PresetShapeTuningSeamTests`). Each layout is
    /// tuned for the screen its first space sits on in THIS plan.
    /// `nil` where the hardware is not knowable: no shape tuning,
    /// as `mode(of:on:)` keeps the historic answer there.
    public func settings(sizes: [CGSize]?) -> TilingSettings {
        switch tuning {
        case .resolved(let settings):
            // Derived for the screens it was built for; the
            // starter is rebuilt per screen set, never re-sized.
            return settings
        case .preset(let own):
            var settings = shapeTuning(sizes: sizes)
            own.apply(to: &settings)
            return settings
        }
    }

    private func shapeTuning(sizes: [CGSize]?) -> TilingSettings {
        guard let sizes, !sizes.isEmpty, spaceCount > 0 else {
            return StarterTuning.base()
        }
        let slots = (1...spaceCount).map { number in
            let space = SpaceID(number)
            let screen = screen(of: space, screens: sizes.count)
            return StarterSetup.Slot(
                number: number,
                screen: screen,
                mode: mode(of: space, on: ScreenClass.of(sizes[screen]))
            )
        }
        return StarterSetup.presetSettings(slots: slots, sizes: sizes)
    }
}
