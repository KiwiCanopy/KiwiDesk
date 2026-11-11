import CoreGraphics
import KiwiDeskCore

/// The scroll gestures' diff rows and value words (#1656), in the
/// Mouse & trackpad rows' own labels.
extension SettingsValueReadout {
    static func scrollGestureRows(
        _ key: ShortcutsKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        guard let field = ScrollGestureWords.field(of: key) else {
            return []
        }
        let before = field.value(in: old.scrollGesture)
        let after = field.value(in: new.scrollGesture)
        return [
            .change(
                .shortcuts(key),
                label: ScrollGestureWords.label(field),
                old: ScrollGestureWords.value(before),
                new: ScrollGestureWords.value(after)
            )
        ]
    }
}

/// What a scroll-gesture row is called and how its value reads —
/// one home for the diff pill, the "Applies to" checklist and the
/// rows' spoken names.
@MainActor
enum ScrollGestureWords {
    /// The census key's field.
    static func field(of key: ShortcutsKey) -> ScrollGestureField? {
        switch key {
        case .scrollLongSwipes: .longSwipes
        case .scrollStepDistance: .stepDistance
        case .scrollNaturalTrackpad: .naturalTrackpad
        case .scrollNaturalMouse: .naturalMouse
        default: nil
        }
    }

    static var pan: String {
        L("shortcuts.gestures.scroll.pan", "Scroll through windows")
    }

    static var longSwipes: String {
        L(
            "shortcuts.gestures.scroll.long_swipes",
            "Long swipes move more windows"
        )
    }

    static var stepDistance: String {
        L("shortcuts.gestures.scroll.step_distance", "Travel per window")
    }

    static var trackpad: String {
        L("shortcuts.gestures.scroll.trackpad", "Trackpad")
    }

    static var mouse: String {
        L("shortcuts.gestures.scroll.mouse", "Mouse")
    }

    /// Apple's own toggle name (TrackpadExtension ▸
    /// `GNAME_SCROLL_NEW`), verbatim per locale.
    static var natural: String {
        L("shortcuts.gestures.scroll.natural", "Natural scrolling")
    }

    /// One Natural scrolling choice: macOS's, or pinned.
    static func natural(_ value: NaturalScrolling) -> String {
        switch value {
        case .system:
            L("shortcuts.gestures.scroll.natural_system", "System")
        case .on: SettingsValueReadout.onOff(true)
        case .off: SettingsValueReadout.onOff(false)
        }
    }

    /// Apple's subtitle under it (`GNAME_SCROLL_LABEL`).
    static var naturalCaption: String {
        L(
            "shortcuts.gestures.scroll.natural_caption",
            "Content tracks finger movement"
        )
    }

    /// A row's label as the diff and the checklist name it.
    static func label(_ field: ScrollGestureField) -> String {
        switch field {
        case .longSwipes: longSwipes
        case .stepDistance: stepDistance
        case .naturalTrackpad:
            SettingsValueReadout.instanceLabel(natural, trackpad)
        case .naturalMouse:
            SettingsValueReadout.instanceLabel(natural, mouse)
        }
    }

    /// A value in words: On/Off, a Natural scrolling choice, points.
    static func value(_ value: ScrollGestureValue) -> String {
        switch value {
        case .flag(let on): SettingsValueReadout.onOff(on)
        case .natural(let natural): ScrollGestureWords.natural(natural)
        case .points(let points):
            SettingsValueReadout.points(CGFloat(points))
        }
    }
}
