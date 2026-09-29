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
        case .scrollPan: .pan
        case .scrollLongSwipes: .longSwipes
        case .scrollStepDistance: .stepDistance
        case .scrollNaturalTrackpad: .naturalTrackpad
        case .scrollNaturalMouse: .naturalMouse
        case .scrollSpaceStep: .spaceStep
        default: nil
        }
    }

    /// The row a gesture's chord is stored in.
    static func field(
        of consumer: ScrollGestures.Consumer
    ) -> ScrollGestureField {
        switch consumer {
        case .pan: .pan
        case .step: .spaceStep
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
        case .pan: pan
        case .spaceStep:
            L("shortcuts.gestures.scroll.space_step", "Step between Spaces")
        case .longSwipes: longSwipes
        case .stepDistance: stepDistance
        case .naturalTrackpad:
            SettingsValueReadout.instanceLabel(natural, trackpad)
        case .naturalMouse:
            SettingsValueReadout.instanceLabel(natural, mouse)
        }
    }

    /// A value in words: a chord's keycaps, On/Off, points.
    static func value(_ value: ScrollGestureValue) -> String {
        switch value {
        case .chord(let chord):
            chord.isEmpty
                ? SettingsValueReadout.onOff(false)
                : ScrollChordGlyphs.text(chord)
        case .flag(let on): SettingsValueReadout.onOff(on)
        case .points(let points):
            SettingsValueReadout.points(CGFloat(points))
        }
    }
}
