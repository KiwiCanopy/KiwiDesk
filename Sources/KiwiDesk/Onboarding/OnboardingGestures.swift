import Foundation
import KiwiDeskCore

/// The tour's Gestures step rows (#1873 ▸ Ruling 2026-11-15,
/// preview `tour-gestures-v2`): at most five, in words, each read
/// from the live bindings, so a row the user unbound is not
/// taught — move focus, switch Spaces, the Desktop overview, the
/// screen (with two or more screens) and KiwiVision — then ⌃⌥K for
/// the rest.
@MainActor
enum OnboardingGestures {
    static let limit = 5

    static func families(
        bindings: [GestureKey: GestureAction],
        screens: Int,
        layer: KeyLayer?
    ) -> [OnboardingKeyFamily] {
        let keys = bindings.keys.sorted()
        // The ladder (#1873): the Spaces row teaches three fingers,
        // so a two-finger alias is its last resort.
        func swipe(
            twoLast: Bool = false,
            _ holds: (GestureAction) -> Bool
        ) -> GestureKey? {
            let order =
                twoLast
                ? keys.filter { $0.input != .swipe2 }
                    + keys.filter { $0.input == .swipe2 }
                : keys
            return order.first {
                $0.input.device == .trackpad
                    && !$0.input.directions.isEmpty
                    && bindings[$0].map(holds) == true
            }
        }
        var rows: [OnboardingKeyFamily] = []
        if let key = swipe({ $0.step(toward: .left) == .family(.focus) }) {
            rows.append(
                row(
                    "focus",
                    L("onboarding.gestures.focus", "Move focus"),
                    key,
                    fingers(key)
                )
            )
        }
        if let key = swipe(
            twoLast: true,
            { $0.step(toward: .left) == .family(.space) }
        ) {
            let whole = bindings[key]?.step(toward: .up) == .family(.space)
            rows.append(
                row(
                    "space",
                    L("onboarding.gestures.space", "Switch Spaces"),
                    key,
                    whole ? fingers(key) : sideways(key)
                )
            )
        }
        if let key = swipe({ action in
            guard case .lua(let run) = action.step(toward: .up) else {
                return false
            }
            return run.lua == KiwiHubSide.desktops.lua
        }) {
            rows.append(
                row(
                    "desktops",
                    L(
                        "onboarding.gestures.desktops",
                        "Open the Desktop overview"
                    ),
                    key,
                    upward(key)
                )
            )
        }
        if screens > 1,
            let key = swipe({ $0.step(toward: .left) == .family(.display) })
        {
            rows.append(
                row(
                    "display",
                    L("onboarding.gestures.display", "Focus another screen"),
                    key,
                    fingers(key)
                )
            )
        }
        if let key = keys.first(where: { key in
            guard key.input.fingers != nil, key.input.directions.isEmpty,
                case .run(let run) = bindings[key]
            else { return false }
            return run.lua == KeybindingCatalog.toggleKiwiVision.lua
        }) {
            rows.append(
                row(
                    "kiwivision",
                    L(
                        "onboarding.gestures.kiwivision",
                        "Turn KiwiVision on or off"
                    ),
                    key,
                    tap(key)
                )
            )
        }
        rows = Array(rows.prefix(limit))
        // ⌃⌥K alone teaches no gesture: no step then.
        if !rows.isEmpty, let gateway = gateway(layer) {
            rows.append(gateway)
        }
        return rows
    }

    /// The sentence under the body, from the rows it sits over: the
    /// focus row repeats only with long swipes on, and screens are
    /// named only beside the row that teaches one.
    static func footnote(
        _ rows: [OnboardingKeyFamily],
        longSwipes: Bool
    ) -> String? {
        let ids = Set(rows.map(\.id))
        var lines: [String] = []
        if ids.contains("focus"), longSwipes {
            lines.append(
                L(
                    "onboarding.gestures.steps_focus",
                    "Focus keeps stepping while your fingers move."
                )
            )
        }
        if ids.contains("display") {
            lines.append(
                L(
                    "onboarding.gestures.steps_screens",
                    "Spaces and screens take one step per swipe."
                )
            )
        } else if ids.contains("space") {
            lines.append(
                L(
                    "onboarding.gestures.steps_spaces",
                    "Spaces take one step per swipe."
                )
            )
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    private static func row(
        _ id: String,
        _ label: String,
        _ key: GestureKey,
        _ motion: String
    ) -> OnboardingKeyFamily {
        let modifiers = HotkeyModifiers(key.chord)
        let spoken =
            key.chord.isEmpty
            ? L("onboarding.gestures.spoken", "%1$@: %2$@", label, motion)
            : L(
                "onboarding.gestures.spoken_chord",
                "%1$@: %2$@, %3$@",
                label,
                ScrollChordGlyphs.spoken(key.chord),
                motion
            )
        return OnboardingKeyFamily(
            id: id,
            label: label,
            chord: .shared(modifiers, keys: motion),
            spoken: spoken
        )
    }

    // One key per finger count and motion: the count is a closed set,
    // so no frame asks a noun to agree with a number.

    private static func fingers(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 3: L("onboarding.gestures.fingers.3", "3 fingers")
        case 4: L("onboarding.gestures.fingers.4", "4 fingers")
        case 5: L("onboarding.gestures.fingers.5", "5 fingers")
        default: L("onboarding.gestures.fingers.2", "2 fingers")
        }
    }

    private static func sideways(_ key: GestureKey) -> String {
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

    private static func upward(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 2: L("onboarding.gestures.up.2", "2 fingers up")
        case 4: L("onboarding.gestures.up.4", "4 fingers up")
        case 5: L("onboarding.gestures.up.5", "5 fingers up")
        default: L("onboarding.gestures.up.3", "3 fingers up")
        }
    }

    private static func tap(_ key: GestureKey) -> String {
        switch key.input.fingers {
        case 2: L("onboarding.gestures.tap.2", "2-finger tap")
        case 3: L("onboarding.gestures.tap.3", "3-finger tap")
        case 5: L("onboarding.gestures.tap.5", "5-finger tap")
        default: L("onboarding.gestures.tap.4", "4-finger tap")
        }
    }

    /// ⌃⌥K: every gesture, set apart as the keys step sets KiwiHub.
    private static func gateway(_ layer: KeyLayer?) -> OnboardingKeyFamily? {
        guard let layer,
            let combo = OnboardingKeys.combo(
                lua: KiwiHubSide.shortcuts.lua,
                in: layer
            ),
            let chord = OnboardingKeys.single(combo: combo)
        else { return nil }
        return OnboardingKeyFamily(
            id: "kiwihub",
            label: L(
                "onboarding.gestures.all",
                "Every gesture, and what it does"
            ),
            chord: chord,
            isGateway: true
        )
    }
}

extension HotkeyModifiers {
    /// The keys a gesture holds, as the keycaps draw them.
    init(_ chord: ScrollChord) {
        var keys: HotkeyModifiers = []
        if chord.contains(.control) { keys.insert(.control) }
        if chord.contains(.option) { keys.insert(.option) }
        if chord.contains(.shift) { keys.insert(.shift) }
        if chord.contains(.command) { keys.insert(.command) }
        self = keys
    }
}
