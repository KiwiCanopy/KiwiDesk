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

    /// A bare key binding gets a chip like any other. An earlier
    /// cut dropped it because it has no modifier glyph to show,
    /// which meant a binding on plain `L` or `return` appeared
    /// NOWHERE on a board whose question is what is taken
    /// (owner, 2026-08-10). It holds the fewest modifiers, so it
    /// sorts first; the word naming it is the view's.
    @Test("A bare key binding still gets a chip, and leads")
    func unmodifiedComboIsItsOwnLayer() {
        let only = KeyboardCensus.layers(in: [layer(["j"])])
        #expect(only.count == 1)
        #expect(only.first?.modifiers.isEmpty == true)
        #expect(only.first?.label == "")

        let mixed = KeyboardCensus.layers(
            in: [layer(["j", "ctrl+alt+k"])]
        )
        #expect(mixed.first?.modifiers.isEmpty == true)
    }

    @Test("A bare binding claims its key like any other")
    func unmodifiedComboClaimsItsKey() {
        let layers = [layer(["j"])]
        let plain = KeyboardCensus.ModifierLayer(modifiers: [])
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: [plain]
        )
        #expect(claims[38] == [plain])
        #expect(
            KeyboardCensus.takenKeyCount(claims: claims) == 1
        )
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

    /// `bindings(on:)` and `claims` are two folds over one
    /// array, and the whole reason the first sits beside the
    /// second is that they cannot disagree — a key the fills
    /// draw as free must not be named by the words. Placement
    /// asserted that in prose; this asserts it (#798 review).
    @Test("the per-key fold agrees with the claims fold")
    func perKeyFoldAgreesWithClaims() {
        let layers = [
            layer(["alt+j", "ctrl+alt+j", "ctrl+alt+k", "j"])
        ]
        let selected = Set(KeyboardCensus.layers(in: layers))
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: selected
        )
        #expect(!claims.isEmpty)
        // Every key the fills claim, and every key they do not.
        for code in Set(claims.keys).union([13, 14, 49]) {
            let named = Set(
                KeyboardCensus.bindings(
                    on: code,
                    in: layers,
                    selected: selected
                )
                .map(\.layer)
            )
            #expect(
                named == Set(claims[code] ?? []),
                Comment(
                    rawValue: "key \(code): the words name "
                        + "\(named.map(\.label)) and the fills "
                        + "claim \(claims[code]?.map(\.label) ?? [])"
                )
            )
        }
        // …and a narrowed selection narrows both alike.
        let one = Set([
            KeyboardCensus.ModifierLayer(modifiers: .option)
        ])
        let narrow = KeyboardCensus.claims(
            in: layers,
            selected: one
        )
        #expect(
            Set(
                KeyboardCensus.bindings(
                    on: 38,
                    in: layers,
                    selected: one
                )
                .map(\.layer)
            ) == Set(narrow[38] ?? [])
        )
    }

    @Test("A key claimed in two layers is one key, two stripes")
    func tallyCountsKeysAndModifiers() {
        let layers = [layer(["alt+j", "ctrl+alt+j", "ctrl+alt+k"])]
        let selected = Set(KeyboardCensus.layers(in: layers))
        let claims = KeyboardCensus.claims(
            in: layers,
            selected: selected
        )
        #expect(
            KeyboardCensus.takenKeyCount(claims: claims) == 2
        )
    }

    @Test("The tally follows the selection down to nothing")
    func tallyEmptiesWithTheSelection() {
        let claims = KeyboardCensus.claims(
            in: [layer(["alt+j"])],
            selected: []
        )
        #expect(
            KeyboardCensus.takenKeyCount(claims: claims) == 0
        )
    }

    @Test("Reserved is answered under the selection, not blind")
    func systemReservedIsPerModifier() {
        // W (13) is Close Window under ⌘, free under ⌃⌥.
        // Space was this fixture's example until #1094 put
        // ⌃⌥space (next input source) in the map — ⌃⌥ is the
        // quiet base, but since then it is not the empty one.
        let command = KeyboardCensus.ModifierLayer(
            modifiers: .command
        )
        let ctrlOpt = KeyboardCensus.ModifierLayer(
            modifiers: [.control, .option]
        )
        #expect(
            SystemShortcuts.map[
                KeyCombo(keyCode: 13, modifiers: .command)
            ] != nil
        )
        #expect(
            KeyboardCensus.isSystemReserved(13, under: [command])
        )
        #expect(
            !KeyboardCensus.isSystemReserved(13, under: [ctrlOpt])
        )
    }

    /// Under `.all` a key is never "can't bind": macOS reserves
    /// a key UNDER a modifier, so the answer has no meaning until
    /// one is chosen, and blacking keys out there would claim
    /// they are unavailable everywhere.
    @Test("The all-scope reports no reserved keys")
    func allScopeHasNoReservedState() {
        #expect(
            KeyboardCensus.state(
                of: 49,
                claims: [:],
                scope: .all
            ) == .free
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
                scope: .one(command)
            ) == .bound
        )
    }

    /// The premise that keyCode 13 is unreserved under ⌃⌥ is
    /// pinned by `systemReservedIsPerModifier` above, not here.
    /// If a real ⌃⌥W reservation ever lands, THIS test reds with
    /// a message that reads like a `KeyboardCensus.state`
    /// regression — look one test up first. Space expired out of
    /// this fixture exactly that way in #1094.
    @Test("An unclaimed, unreserved key reads free")
    func freeIsTheRemainder() {
        let ctrlOpt = KeyboardCensus.ModifierLayer(
            modifiers: [.control, .option]
        )
        #expect(
            KeyboardCensus.state(
                of: 13,
                claims: [:],
                scope: .one(ctrlOpt)
            ) == .free
        )
    }
}
