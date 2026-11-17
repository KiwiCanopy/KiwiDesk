import KiwiDeskCore

/// The Gestures step's devices (#3427 ▸ Ruling): each device's rows,
/// which one the step shows, and whether it offers Trackpad | Mouse.
extension OnboardingModel {
    /// The rows the step shows now.
    var gestureFamilies: [OnboardingKeyFamily] {
        gestureRowsByDevice[gestureDevice] ?? []
    }

    /// Whether the step offers Trackpad | Mouse: both have rows.
    var offersGestureDevices: Bool { gestureRowsByDevice.count == 2 }

    /// Reads each device's rows and picks the one shown: a Mac
    /// without a trackpad has mouse rows only.
    func planGestures() {
        var rows: [GestureInput.Device: [OnboardingKeyFamily]] = [:]
        if hasTrackpad() {
            let trackpad = gestureRows()
            if !trackpad.isEmpty { rows[.trackpad] = trackpad }
        }
        let mouse = mouseGestureRows()
        if !mouse.isEmpty { rows[.mouse] = mouse }
        gestureRowsByDevice = rows
        gestureDevice = rows[.trackpad] == nil ? .mouse : .trackpad
    }
}
