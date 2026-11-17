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
        func first(
            _ input: GestureInput,
            _ holds: (GestureAction) -> Bool
        ) -> GestureKey? {
            keys.first { $0.input == input && bindings[$0].map(holds) == true }
        }
        let focus = L("onboarding.gestures.focus", "Move focus")
        let space = L("onboarding.gestures.space", "Switch Spaces")
        var rows: [OnboardingKeyFamily] = []
        if let key = first(.wheel, { Self.family($0)?.runsThePan == true }) {
            rows.append(mouse("focus", focus, key, scroll))
        }
        if let key = first(.wheelX, { Self.family($0) == .space }) {
            rows.append(mouse("space", space, key, scrollSideways))
        }
        if let key = first(.drag, { $0 == .grab(.move) }) {
            rows.append(
                mouse(
                    "move",
                    L("onboarding.gestures.move_window", "Move a window"),
                    key,
                    drag
                )
            )
        }
        if let key = first(.drag, { $0 == .grab(.resize) }) {
            rows.append(
                mouse(
                    "resize",
                    L("onboarding.gestures.resize_window", "Resize a window"),
                    key,
                    drag
                )
            )
        }
        if let key = first(.sideButtons, { Self.family($0) != nil }),
            let family = bindings[key].flatMap(Self.family)
        {
            let label = family == .space ? space : focus
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

    /// The family a whole-input binding runs, nil for any other.
    private static func family(_ action: GestureAction) -> GestureFamily? {
        if case .family(let family) = action { return family }
        return nil
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
