import KiwiDeskCore

/// The gesture pop-up's glyphs and groups (#3281).
extension GestureListWords {
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
        case .spread4:
            "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .pinchTogether4: "arrow.down.right.and.arrow.up.left"
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
            (
                L("shortcuts.gestures.group.pinch", "Pinch & Rotate"),
                { $0.isGestureEvent }
            ),
        ]
        return groups.compactMap { title, holds in
            let inputs = offered.filter(holds)
            return inputs.isEmpty ? nil : (title, inputs)
        }
    }
}
