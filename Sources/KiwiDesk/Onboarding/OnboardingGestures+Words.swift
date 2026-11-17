import KiwiDeskCore

/// A tour gesture's cap (#3427): the `GestureGlyph` name and the
/// caption drawn under it.
struct OnboardingGestureCap: Equatable {
    let glyph: String
    let caption: String
}

/// The tour's gesture words, one key per finger count and motion:
/// the count is a closed set, so no frame asks a noun to agree with
/// a number.
extension OnboardingGestures {
    static func fingers(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 3: L("onboarding.gestures.fingers.3", "3 fingers")
        case 4: L("onboarding.gestures.fingers.4", "4 fingers")
        case 5: L("onboarding.gestures.fingers.5", "5 fingers")
        default: L("onboarding.gestures.fingers.2", "2 fingers")
        }
    }

    static func sideways(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 2:
            L("onboarding.gestures.sideways.2", "2 fingers left/right")
        case 4:
            L("onboarding.gestures.sideways.4", "4 fingers left/right")
        case 5:
            L("onboarding.gestures.sideways.5", "5 fingers left/right")
        default:
            L("onboarding.gestures.sideways.3", "3 fingers left/right")
        }
    }

    static func upward(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 2: L("onboarding.gestures.up.2", "2 fingers up")
        case 4: L("onboarding.gestures.up.4", "4 fingers up")
        case 5: L("onboarding.gestures.up.5", "5 fingers up")
        default: L("onboarding.gestures.up.3", "3 fingers up")
        }
    }

    static func tap(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 2: L("onboarding.gestures.tap.2", "2-finger tap")
        case 3: L("onboarding.gestures.tap.3", "3-finger tap")
        case 5: L("onboarding.gestures.tap.5", "5-finger tap")
        default: L("onboarding.gestures.tap.4", "4-finger tap")
        }
    }
}
