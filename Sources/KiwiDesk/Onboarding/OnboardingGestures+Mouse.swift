import KiwiDeskCore

/// The Gestures step's mouse rows (#3427 ▸ Ruling): at most five,
/// each read from the live bindings — move focus and switch Spaces
/// by scrolling, move and resize a window by dragging, then the side
/// buttons where bound — then ⌃⌥K. Every row's cap is the mouse,
/// its motion under it.
extension OnboardingGestures {
    /// The mouse cap's glyph, an SF Symbol `GestureGlyph` draws.
    static let mouseGlyph = "computermouse"

    static func mouseFamilies(
        bindings: [GestureKey: GestureAction],
        layer: KeyLayer?
    ) -> [OnboardingKeyFamily] {
        let keys = bindings.keys.sorted()
        // Read as the trackpad rows read theirs: what one way of
        // `input` steps to.
        func first(
            _ input: GestureInput,
            toward way: GestureDirection?,
            _ holds: (GestureStep?) -> Bool
        ) -> GestureKey? {
            keys.first {
                $0.input == input && holds(bindings[$0]?.step(toward: way))
            }
        }
        // A drag binds a grab, which no way steps through.
        func grab(_ action: ModifierDragAction) -> GestureKey? {
            keys.first { $0.input == .drag && bindings[$0] == .grab(action) }
        }
        let focus = L("onboarding.gestures.focus", "Move focus")
        let space = L("onboarding.gestures.space", "Switch Spaces")
        var rows: [OnboardingKeyFamily] = []
        if let key = first(.wheel, toward: .up, { Self.pans($0) }) {
            rows.append(mouse("focus", focus, key, scroll))
        }
        if let key = first(.wheelX, toward: .left, { $0 == .family(.space) }) {
            rows.append(mouse("space", space, key, scrollSideways))
        }
        if let key = grab(.move) {
            rows.append(
                mouse(
                    "move",
                    L("onboarding.gestures.move_window", "Move a window"),
                    key,
                    drag
                )
            )
        }
        if let key = grab(.resize) {
            rows.append(
                mouse(
                    "resize",
                    L("onboarding.gestures.resize_window", "Resize a window"),
                    key,
                    drag
                )
            )
        }
        // The side buttons teach the two things the step names: a
        // focus that pans, or the Space step.
        let toSpace: (GestureStep?) -> Bool = { $0 == .family(.space) }
        let teaches: (GestureStep?) -> Bool = { pans($0) || toSpace($0) }
        if let key = first(.sideButtons, toward: .back, teaches) {
            let step = bindings[key]?.step(toward: .back)
            let label = toSpace(step) ? space : focus
            rows.append(mouse("buttons", label, key, sideButtons))
        }
        rows = Array(rows.prefix(limit))
        // ⌃⌥K alone teaches no gesture: no rows then.
        if !rows.isEmpty, let gateway = gateway(layer) {
            rows.append(gateway)
        }
        return rows
    }

    /// The sentence under the mouse body: a scrolled focus or Space
    /// row steps once per notch, as far as the wheel turns.
    static func mouseFootnote(_ rows: [OnboardingKeyFamily]) -> String? {
        let ids = Set(rows.map(\.id))
        switch (ids.contains("focus"), ids.contains("space")) {
        case (true, true):
            return L(
                "onboarding.gestures.mouse_steps_both",
                "Focus and Spaces step as far as you scroll."
            )
        case (true, false):
            return L(
                "onboarding.gestures.mouse_steps_focus",
                "Focus steps as far as you scroll."
            )
        case (false, true):
            return L(
                "onboarding.gestures.mouse_steps_spaces",
                "Spaces step as far as you scroll."
            )
        case (false, false):
            return nil
        }
    }

    /// Whether `step` runs the pan, focus moving as far as the
    /// wheel turns (`GestureFamily.runsThePan`).
    private static func pans(_ step: GestureStep?) -> Bool {
        if case .family(let family) = step { return family.runsThePan }
        return false
    }

    private static func mouse(
        _ id: String,
        _ label: String,
        _ key: GestureKey,
        _ motion: String
    ) -> OnboardingKeyFamily {
        row(
            id,
            label,
            key,
            motion,
            OnboardingGestureCap(glyph: mouseGlyph, caption: motion)
        )
    }

    private static var scroll: String {
        L("onboarding.gestures.mouse.scroll", "scroll")
    }

    private static var scrollSideways: String {
        L("onboarding.gestures.mouse.scroll_sideways", "scroll sideways")
    }

    private static var drag: String {
        L("onboarding.gestures.mouse.drag", "drag")
    }

    private static var sideButtons: String {
        L("onboarding.gestures.mouse.side_buttons", "side buttons")
    }
}
