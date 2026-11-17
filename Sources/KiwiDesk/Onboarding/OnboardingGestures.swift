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
        // The ways `key` reaches what its row teaches, which pick its
        // badge as KiwiHub picks it (`ShortcutGestureBadge.covering`).
        func ways(
            _ key: GestureKey,
            _ hits: (GestureStep?) -> Bool
        ) -> Set<GestureDirection> {
            Set(
                key.input.directions.filter {
                    hits(bindings[key]?.step(toward: $0))
                }
            )
        }
        var rows: [OnboardingKeyFamily] = []
        if let key = swipe({ $0.step(toward: .left) == .family(.focus) }) {
            let reach = ways(key) { $0 == .family(.focus) }
            rows.append(
                row(
                    "focus",
                    L("onboarding.gestures.focus", "Move focus"),
                    key,
                    motion(key, reach),
                    badge(key, reach)
                )
            )
        }
        if let key = swipe(
            twoLast: true,
            { $0.step(toward: .left) == .family(.space) }
        ) {
            let reach = ways(key) { $0 == .family(.space) }
            rows.append(
                row(
                    "space",
                    L("onboarding.gestures.space", "Switch Spaces"),
                    key,
                    motion(key, reach),
                    badge(key, reach)
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
                    upward(key),
                    badge(
                        key,
                        ways(key) {
                            guard case .lua(let run) = $0 else { return false }
                            return run.lua == KiwiHubSide.desktops.lua
                        }
                    )
                )
            )
        }
        if screens > 1,
            let key = swipe({ $0.step(toward: .left) == .family(.display) })
        {
            let reach = ways(key) { $0 == .family(.display) }
            rows.append(
                row(
                    "display",
                    L("onboarding.gestures.display", "Focus another screen"),
                    key,
                    motion(key, reach),
                    badge(key, reach)
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
                    tap(key),
                    badge(key, [], caption: tap(key))
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

    /// The motion VoiceOver reads for a swipe reaching its row along
    /// `ways`, so the words name the way the arrows draw: left and
    /// right alone as a sideways swipe, every way as the swipe.
    private static func motion(
        _ key: GestureKey,
        _ ways: Set<GestureDirection>
    ) -> String {
        ShortcutGestureBadge.Axis.of(ways) == .horizontal
            ? sideways(key) : fingers(key)
    }

    private static func badge(
        _ key: GestureKey,
        _ ways: Set<GestureDirection>,
        caption: String? = nil
    ) -> OnboardingGestureCap {
        OnboardingGestureCap(
            glyph: ShortcutGestureBadge.covering(key, ways: ways).symbol,
            caption: caption ?? fingers(key)
        )
    }

    /// One row: the keys, the gesture's cap, and the whole motion in
    /// words for VoiceOver alone.
    static func row(
        _ id: String,
        _ label: String,
        _ key: GestureKey,
        _ motion: String,
        _ cap: OnboardingGestureCap
    ) -> OnboardingKeyFamily {
        let modifiers = HotkeyModifiers(key.chord)
        let spoken =
            key.chord.isEmpty
            ? L("onboarding.gestures.spoken", "%1$@: %2$@", label, motion)
            : L(
                "onboarding.gestures.spoken_chord",
                "%1$@: %2$@, %3$@",
                label,
                SidedChordWords.label(ScrollChordGlyphs.text(key.chord)),
                motion
            )
        return OnboardingKeyFamily(
            id: id,
            label: label,
            chord: .gesture(
                modifiers,
                glyph: cap.glyph,
                caption: cap.caption
            ),
            spoken: spoken
        )
    }

    /// ⌃⌥K: every gesture, set apart as the keys step sets KiwiHub.
    static func gateway(_ layer: KeyLayer?) -> OnboardingKeyFamily? {
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
        if chord.contains(.hyper) { keys.insert(.hyper) }
        if chord.contains(.control) { keys.insert(.control) }
        if chord.contains(.option) { keys.insert(.option) }
        if chord.contains(.shift) { keys.insert(.shift) }
        if chord.contains(.command) { keys.insert(.command) }
        self = keys
    }
}
