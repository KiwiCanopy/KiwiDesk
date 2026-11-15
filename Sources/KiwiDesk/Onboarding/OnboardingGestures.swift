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
        if let gateway = gateway(layer) { rows.append(gateway) }
        return rows
    }

    /// Whether any row teaches a screen: the sentence under the
    /// body names screens only beside the row that does.
    static func teachesScreens(_ rows: [OnboardingKeyFamily]) -> Bool {
        rows.contains { $0.id == "display" }
    }

    private static func row(
        _ id: String,
        _ label: String,
        _ key: GestureKey,
        _ motion: String
    ) -> OnboardingKeyFamily {
        let modifiers = HotkeyModifiers(key.chord)
        return OnboardingKeyFamily(
            id: id,
            label: label,
            chord: .shared(modifiers, keys: motion),
            spoken: L(
                "onboarding.gestures.spoken",
                "%1$@: %2$@",
                label,
                key.chord.isEmpty
                    ? motion
                    : SidedChordWords.label(
                        ScrollChordGlyphs.text(key.chord)
                    ) + ", " + motion
            )
        )
    }

    private static func count(_ key: GestureKey) -> Int {
        key.input.fingers ?? 2
    }

    private static func fingers(_ key: GestureKey) -> String {
        L("onboarding.gestures.fingers", "%1$d fingers", count(key))
    }

    private static func sideways(_ key: GestureKey) -> String {
        L(
            "onboarding.gestures.fingers_sideways",
            "%1$d fingers left/right",
            count(key)
        )
    }

    private static func upward(_ key: GestureKey) -> String {
        L("onboarding.gestures.fingers_up", "%1$d fingers up", count(key))
    }

    private static func tap(_ key: GestureKey) -> String {
        L("onboarding.gestures.tap", "%1$d-finger tap", count(key))
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
