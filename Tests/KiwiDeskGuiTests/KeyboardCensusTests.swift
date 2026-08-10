import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The keyboard preview's arithmetic, asserted directly rather
/// than through the drawing. A renderer that takes the fold and
/// draws a constant satisfies any source scan while answering
/// nothing — the `LayoutSchematicCountTests` lesson.
@Suite("Keyboard preview census")
struct KeyboardCensusTests {

    private func layer(
        _ combos: [String],
        name: String = KeyLayer.defaultName
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            bindings: combos.enumerated().map { index, combo in
                KeyBinding(
                    combo: combo,
                    lua: "focus_dir('left')",
                    label: "row \(index)"
                )
            }
        )
    }

    /// Watches `KeyCombo.parse` rejecting the empty string, which
    /// is what actually keeps a row waiting for its chord out of
    /// the tally — stated because the obvious reading is that a
    /// filter in `combos` does it, and a filter there would be
    /// unreachable.
    @Test("An unrecorded row claims no key")
    func emptyComboIsNotTaken() {
        #expect(KeyCombo.parse("") == nil)
        let layers = [layer(["ctrl+alt+j", "", "ctrl+alt+k"])]
        #expect(KeyboardCensus.combos(in: layers).count == 2)
    }

    @Test("The modifier layers are derived, not a fixed set")
    func layersComeFromTheBindings() {
        let only = KeyboardCensus.layers(
            in: [layer(["alt+j", "alt+k"])]
        )
        #expect(only.count == 1)
        #expect(only.first?.label == "⌥")

        let two = KeyboardCensus.layers(
            in: [layer(["alt+j", "ctrl+alt+k"])]
        )
        #expect(two.map(\.label) == ["⌥", "⌃⌥"])
    }

    @Test("A bare key binding offers no chip")
    func unmodifiedComboIsNoLayer() {
        #expect(KeyboardCensus.layers(in: [layer(["j"])]).isEmpty)
    }

    /// The combinations here are chosen so the two candidate
    /// orders DISAGREE. Carbon's masks run ⌘ 256, ⇧ 512, ⌥ 2048,
    /// ⌃ 4096, so a lone ⌃ (4096) outranks ⇧⌘ (768) by raw
    /// value while holding fewer keys — sorting on the mask
    /// alone puts the two-modifier chip first. An earlier cut of
    /// this test used ⌥ / ⌃⌥ / ⌃⌥⇧, where both orders agree, and
    /// it passed with the bit-count arm deleted.
    @Test("Chips lead with the fewest modifiers held")
    func chipOrderIsStable() {
        let sorted = KeyboardCensus.layers(
            in: [layer(["shift+cmd+j", "ctrl+k"])]
        )
        #expect(sorted.map(\.label) == ["⌃", "⇧⌘"])
    }

    /// The tiebreak, which the test above cannot reach: two
    /// combinations holding the SAME number of modifiers still
    /// need a deterministic order, or the chip row reshuffles
    /// between renders — the layer set is built from a `Set`, so
    /// without it the order is whatever hashing gave that time.
    /// ⇧⌘ is 768 and ⌃⌥ is 6144, both two keys held.
    @Test("Equal-sized combinations still order deterministically")
    func chipOrderBreaksTiesByMask() {
        let sorted = KeyboardCensus.layers(
            in: [layer(["ctrl+alt+j", "shift+cmd+k"])]
        )
        #expect(sorted.map(\.label) == ["⇧⌘", "⌃⌥"])
    }

    @Test("Only the selected layers claim a key")
    func claimsFollowTheSelection() {
        let layers = [layer(["alt+j", "ctrl+alt+k"])]
        let option = KeyboardCensus.ModifierLayer(
            modifiers: .option
        )
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: [option]
        )
        // j = 38, k = 40.
        #expect(claims[38] == [option])
        #expect(claims[40] == nil)
    }

    @Test("One key claimed by two layers keeps both stripes")
    func twoLayersStripeOneKey() {
        let layers = [layer(["alt+j", "ctrl+alt+j"])]
        let selected = Set(KeyboardCensus.layers(in: layers))
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: selected
        )
        #expect(claims[38]?.count == 2)
        #expect(claims[38]?.map(\.label) == ["⌥", "⌃⌥"])
    }

    @Test("A key claimed in two layers is one key, two stripes")
    func tallyCountsKeysAndModifiers() {
        let layers = [layer(["alt+j", "ctrl+alt+j", "ctrl+alt+k"])]
        let selected = Set(KeyboardCensus.layers(in: layers))
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: selected
        )
        let tally = KeyboardCensus.tally(claims: claims)
        #expect(tally.keys == 2)
        #expect(tally.modifiers == 2)
    }

    @Test("The tally follows the selection down to nothing")
    func tallyEmptiesWithTheSelection() {
        let claims = KeyboardCensus.claims(
            in: [layer(["alt+j"])],
            selected: []
        )
        let tally = KeyboardCensus.tally(claims: claims)
        #expect(tally.keys == 0)
        #expect(tally.modifiers == 0)
    }

    @Test("Reserved is answered under the selection, not blind")
    func systemReservedIsPerModifier() {
        // Space (49) is Spotlight under ⌘, free under ⌃⌥.
        let command = KeyboardCensus.ModifierLayer(
            modifiers: .command
        )
        let ctrlOpt = KeyboardCensus.ModifierLayer(
            modifiers: [.control, .option]
        )
        #expect(
            SystemShortcuts.map[
                KeyCombo(keyCode: 49, modifiers: .command)
            ] != nil
        )
        #expect(
            KeyboardCensus.isSystemReserved(49, under: [command])
        )
        #expect(
            !KeyboardCensus.isSystemReserved(49, under: [ctrlOpt])
        )
    }

    @Test("A bound key reads bound even where macOS reserves it")
    func boundBeatsReserved() {
        let command = KeyboardCensus.ModifierLayer(
            modifiers: .command
        )
        let claims = KeyboardCensus.claims(
            in: [layer(["cmd+space"])],
            selected: [command]
        )
        #expect(
            KeyboardCensus.state(
                of: 49,
                claims: claims,
                selected: [command]
            ) == .bound
        )
    }

    @Test("An unclaimed, unreserved key reads free")
    func freeIsTheRemainder() {
        let ctrlOpt = KeyboardCensus.ModifierLayer(
            modifiers: [.control, .option]
        )
        #expect(
            KeyboardCensus.state(
                of: 49,
                claims: [:],
                selected: [ctrlOpt]
            ) == .free
        )
    }
}

/// The drawn board. Authored geometry, so what these hold is
/// that the authoring stayed self-consistent — a duplicated key
/// code or a row that lost its width is invisible on screen
/// until someone counts.
@Suite("Keyboard preview matrix")
struct KeyboardMatrixTests {

    @Test(
        "Every board draws each key code at most once",
        arguments: [
            KeyboardMatrix.PhysicalType.ansi,
            .iso,
            .jis,
        ]
    )
    func noCodeIsDrawnTwice(
        type: KeyboardMatrix.PhysicalType
    ) {
        let codes = KeyboardMatrix.rows(for: type)
            .flatMap { $0 }
            .compactMap(\.code)
        #expect(Set(codes).count == codes.count)
    }

    @Test("ISO draws the key ANSI does not have")
    func isoAddsItsOwnKey() {
        let ansi = KeyboardMatrix.drawnCodes(for: .ansi)
        let iso = KeyboardMatrix.drawnCodes(for: .iso)
        // 10 = kVK_ISO_Section, beside the left shift.
        #expect(!ansi.contains(10))
        #expect(iso.contains(10))
        #expect(iso.count == ansi.count + 1)
    }

    @Test("The two boards are the same width, row for row")
    func rowsKeepOneWidth() {
        for type in [
            KeyboardMatrix.PhysicalType.ansi, .iso,
        ] {
            let widths = KeyboardMatrix.rows(for: type).map {
                $0.reduce(0) { $0 + $1.units }
            }
            #expect(Set(widths).count == 1, "\(type): \(widths)")
        }
    }

    @Test("Every drawn code is one the app can bind")
    func drawnCodesAreRealKeys() {
        let bindable = Set(KeyCombo.keyCodes.values)
        let drawn = KeyboardMatrix.drawnCodes(for: .ansi)
        #expect(drawn.subtracting(bindable).isEmpty)
    }

    @Test("The free tally counts drawn keys, not alias entries")
    func drawnCodesDeduplicateAliases() {
        // `keyCodes` collapses aliases onto one code, so its
        // count overstates the keyboard.
        #expect(
            KeyCombo.keyCodes.count
                > Set(KeyCombo.keyCodes.values).count
        )
        let drawn = KeyboardMatrix.drawnCodes(for: .ansi)
        #expect(drawn.count < KeyCombo.keyCodes.count)
    }
}
