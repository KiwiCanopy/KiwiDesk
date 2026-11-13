import KiwiDeskCore

/// The gesture list's words (#3183): what each input, family,
/// direction and grab is called on a row. Core names the cases;
/// the GUI narrates them here, once.
@MainActor
enum GestureListWords {
    static func device(_ device: GestureInput.Device) -> String {
        let children = SettingsCatalog.shortcuts.gestures.children
        switch device {
        case .mouse: return children.naturalMouse.text
        case .trackpad: return children.naturalTrackpad.text
        }
    }

    /// The gesture pop-up's item for `input`.
    static func input(_ input: GestureInput) -> String {
        switch input {
        case .drag: L("shortcuts.gestures.input.drag", "Drag")
        case .hoverMove: L("shortcuts.gestures.input.hover_move", "Move")
        case .click: L("shortcuts.gestures.input.click", "Click")
        case .rightClick:
            L("shortcuts.gestures.input.right_click", "Right-click")
        case .wheelClick:
            L("shortcuts.gestures.input.wheel_click", "Wheel click")
        case .sideButtons:
            L("shortcuts.gestures.input.side_buttons", "Side buttons")
        case .wheel: L("shortcuts.gestures.input.wheel", "Scroll")
        case .wheelX:
            L("shortcuts.gestures.input.wheel_x", "Scroll sideways")
        case .tap2: L("shortcuts.gestures.input.tap2", "Two-finger tap")
        case .tap3:
            L("shortcuts.gestures.input.tap3", "Three-finger tap")
        case .tap4: L("shortcuts.gestures.input.tap4", "Four-finger tap")
        case .tap5: L("shortcuts.gestures.input.tap5", "Five-finger tap")
        case .swipe2:
            L("shortcuts.gestures.input.swipe2", "Two-finger swipe")
        case .swipe3:
            L("shortcuts.gestures.input.swipe3", "Three-finger swipe")
        case .swipe4:
            L("shortcuts.gestures.input.swipe4", "Four-finger swipe")
        case .swipe5:
            L("shortcuts.gestures.input.swipe5", "Five-finger swipe")
        // Never offered: no front fires them (#3199 ▸ Ruling).
        case .spread, .pinchTogether, .rotate, .forceClick:
            input.rawValue
        }
    }

    /// The SF Symbol a row's gesture icon and its pop-up item wear
    /// (#3281, ui-designer and owner): an SF Symbol, or a `kiwi.*`
    /// `CustomGlyph` whose dots count a tap's or a swipe's fingers.
    static func symbol(_ input: GestureInput) -> String {
        switch input {
        case .drag: "cursorarrow.and.square.on.square.dashed"
        case .hoverMove: "cursorarrow.motionlines"
        case .wheel: "arrow.up.and.down.text.horizontal"
        case .wheelX: "arrow.left.and.right.text.vertical"
        case .click: CustomGlyph.click.name
        case .rightClick: CustomGlyph.rightClick.name
        case .wheelClick: CustomGlyph.wheelClick.name
        case .sideButtons: CustomGlyph.sideButtons.name
        case .tap2, .tap3, .tap4, .tap5:
            CustomGlyph.taps(input.fingers ?? 2).name
        case .swipe2, .swipe3, .swipe4, .swipe5:
            CustomGlyph.swipes(input.fingers ?? 2).name
        case .spread: "hand.raised.fingers.spread"
        case .pinchTogether: pinch.drawn
        case .rotate: "rotate.right"
        case .forceClick: forceClick.drawn
        }
    }

    /// Two input symbols newer than the deployment floor, each with
    /// the one the floor's macOS draws.
    static let pinch = ShortcutsReferenceBuilder.FloorSymbol(
        name: "hand.pinch",
        floor: "arrow.down.right.and.arrow.up.left"
    )
    static let forceClick = ShortcutsReferenceBuilder.FloorSymbol(
        name: "hand.rays",
        floor: "hand.tap.fill"
    )

    /// The gesture pop-up's groups, in the order a card lists them
    /// (#3281, owner and ui-designer): each keeps `offered`'s order,
    /// and a group with nothing offered is left out.
    static func groups(
        of offered: [GestureInput]
    ) -> [(title: String, inputs: [GestureInput])] {
        let groups: [(String, (GestureInput) -> Bool)] = [
            (
                L("shortcuts.gestures.group.move", "Move & Scroll"),
                { $0.isDrag || $0.isWheel }
            ),
            (
                L("shortcuts.gestures.group.buttons", "Buttons"),
                { $0.isButton }
            ),
            (
                L("shortcuts.gestures.group.tap", "Tap"),
                { $0.fingers != nil && $0.directions.isEmpty }
            ),
            (
                L("shortcuts.gestures.group.swipe", "Swipe"),
                { $0.fingers != nil && !$0.directions.isEmpty }
            ),
        ]
        return groups.compactMap { title, holds in
            let inputs = offered.filter(holds)
            return inputs.isEmpty ? nil : (title, inputs)
        }
    }

    static func family(_ family: GestureFamily) -> String {
        switch family {
        case .focus:
            L("shortcuts.gestures.family.focus", "Focus by direction")
        case .swap:
            L("shortcuts.gestures.family.swap", "Swap by direction")
        case .display:
            L("shortcuts.gestures.family.display", "Focus the next screen")
        case .track:
            L("shortcuts.gestures.family.track", "Move to the next track")
        case .space:
            L("shortcuts.gestures.family.space", "Switch Spaces")
        case .walk:
            L("shortcuts.gestures.family.walk", "Walk the window list")
        }
    }

    /// What one arm of `family` does toward `direction`, in the
    /// direction sub-row's secondary text.
    static func arm(
        _ family: GestureFamily,
        toward direction: GestureDirection
    ) -> String {
        guard let forward = family.stepsForward(direction) else {
            return Self.direction(direction)
        }
        return forward
            ? L("shortcuts.gestures.arm.next", "Next")
            : L("shortcuts.gestures.arm.previous", "Previous")
    }

    static func direction(_ direction: GestureDirection) -> String {
        switch direction {
        case .up: L("shortcuts.gestures.direction.up", "Up")
        case .down: L("shortcuts.gestures.direction.down", "Down")
        case .left: L("shortcuts.gestures.direction.left", "Left")
        case .right: L("shortcuts.gestures.direction.right", "Right")
        case .back: L("shortcuts.gestures.direction.back", "Back")
        case .forward:
            L("shortcuts.gestures.direction.forward", "Forward")
        }
    }

    static func direction(symbol direction: GestureDirection) -> String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left, .back: "arrow.left"
        case .right, .forward: "arrow.right"
        }
    }

    static func grab(_ action: ModifierDragAction) -> String {
        switch action {
        case .move: L("shortcuts.gestures.grab.move", "Move the window")
        case .resize:
            L("shortcuts.gestures.grab.resize", "Resize the window")
        }
    }

    /// A split row's action: per button on the side buttons, per
    /// direction on a motion.
    static func perDirection(_ input: GestureInput) -> String {
        guard input == .sideButtons else {
            return L("shortcuts.gestures.per_direction", "Per direction")
        }
        return L("shortcuts.gestures.per_button", "Per button")
    }

    /// A keyless side-buttons row's caption: the buttons it takes
    /// from every app (#3199 ▸ Ruling, #3281).
    static func takenButtons(_ directions: [GestureDirection]) -> String? {
        if directions == [.back, .forward] {
            return L(
                "shortcuts.gestures.side_buttons.takes_both",
                "Takes Back and Forward from every app, browsers "
                    + "included."
            )
        }
        guard directions.count == 1, let one = directions.first else {
            return nil
        }
        return L(
            "shortcuts.gestures.side_buttons.takes_one",
            "Takes %1$@ from every app, browsers included.",
            direction(one)
        )
    }

    /// A row of mixed directions' caption: a swipe gave up its
    /// slide, a wheel its steps as far as it scrolls.
    static func mixedCaption(_ input: GestureInput) -> String {
        guard input.isWheel else {
            return L(
                "shortcuts.gestures.mixed_caption",
                "Each direction acts once per swipe and no longer "
                    + "slides with your fingers."
            )
        }
        return L(
            "shortcuts.gestures.mixed_caption_wheel",
            "Each direction acts once per scroll, however far you "
                + "scroll."
        )
    }

    static var chooseAction: String {
        L("shortcuts.gestures.choose_action", "Choose action…")
    }

    static var add: String { L("shortcuts.gestures.list.add", "Add") }

    /// A Lua or app action read without the catalogue: its
    /// description, an app's name, else its Lua — "Lua…" while it
    /// has none.
    static func runName(_ run: LuaAction) -> String {
        if !run.meta.desc.trimmed.isEmpty { return run.meta.desc }
        if run.kind == .application,
            let bundleID = KeybindingCatalog.appBundleID(from: run.lua)
        {
            return KeybindingCatalog.displayName(forBundleID: bundleID)
        }
        return run.lua.trimmed.isEmpty ? SequenceActionMenu.luaLabel : run.lua
    }

    /// A row named by its gesture and the keys held with it.
    static func rowName(_ key: GestureKey) -> String {
        guard !key.chord.isEmpty else { return input(key.input) }
        return L(
            "shortcuts.gestures.row_name",
            "%1$@ with %2$@",
            input(key.input),
            ScrollChordGlyphs.text(key.chord)
        )
    }

    /// What a row binds, read without the catalogue: a family's,
    /// a grab's or a split's words, a Lua action's description or
    /// its Lua, off for none.
    static func value(
        _ action: GestureAction?,
        on input: GestureInput? = nil
    ) -> String {
        switch action {
        case nil: SettingsValueReadout.onOff(false)
        case .family(let family): Self.family(family)
        case .grab(let grab): Self.grab(grab)
        case .split: input.map(perDirection) ?? perDirection(.swipe2)
        case .run(let run): runName(run)
        }
    }

    static var restoreDefaults: String {
        L("shortcuts.gestures.list.restore", "Restore Defaults")
    }

    /// Restore Defaults' question while another profile changed
    /// these gestures too (#3248).
    static var restoreAskTitle: String {
        L(
            "shortcuts.gestures.list.restore_ask",
            "Other profiles changed these gestures too."
        )
    }

    /// Who else changed them, then that added rows stay: a paragraph
    /// apart, since a count label ends on its number.
    static func restoreAskMessage(_ others: [String]) -> String {
        RestoreReachWords.changedIn(others) + "\n\n"
            + L(
                "shortcuts.gestures.list.restore_keeps",
                "Gestures you added stay."
            )
    }

    static var magicMouseCaption: String {
        L(
            "shortcuts.gestures.list.magic_mouse",
            "Also applies to the Magic Mouse."
        )
    }

    static var gesture: String {
        L("shortcuts.gestures.list.gesture", "Gesture")
    }
}
