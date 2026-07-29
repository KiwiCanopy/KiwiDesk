import Testing

@testable import KiwiDeskCore

/// Which layout commands promise `.allSpringSized` (#593).
///
/// The whole `stack.*` / `bsp.*` / `scroll.*` surface shares ONE
/// trailing `retile`, so each setter raises the promise where it
/// writes and the dispatcher consumes it. This is the net for a
/// **forgotten** raise — the failure neither of the other guards
/// can see. `BatchSizingRoutingTests` counts occurrences, so it
/// reds when a marking *appears* somewhere unlisted; a pin against
/// `APIReference` would only catch a name renamed out of
/// existence. Neither notices a knob that was never wired, which
/// is the bug that shipped: `bsp.set_ratio_h` raised it and
/// `bsp.set_ratio_h_override` did not — same knob, same retile,
/// two different animations depending on which spelling was typed.
///
/// So every knob is dispatched in **both** spellings. Add a row
/// when a layout gains a ratio-like scalar.
@MainActor
@Suite("Layout commands promise sizing")
struct BatchSizingCommandTests {
    /// `(command, args)` for a ratio-like write. The `_override`
    /// twins take the space id first.
    private static let springSized: [(String, [JSONValue])] = [
        ("bsp.set_ratio_h", [.number(0.6)]),
        ("bsp.set_ratio_v", [.number(0.6)]),
        ("stack.set_master_ratio", [.number(0.6)]),
        ("scroll.set_slot_size", [.number(700)]),
        ("bsp.set_ratio_h_override", [.string("1"), .number(0.6)]),
        ("bsp.set_ratio_v_override", [.string("1"), .number(0.6)]),
        (
            "stack.set_master_ratio_override",
            [.string("1"), .number(0.6)]
        ),
        (
            "scroll.set_slot_size_override",
            [.string("1"), .number(700)]
        ),
    ]

    /// Members of the same dispatch that reassign slots wholesale
    /// and must keep the #45 snap. Both spellings again: the
    /// override arm is a separate switch on a stripped field name,
    /// so it does not resemble the global one and is easy to skim
    /// past when adding a knob.
    private static let mayInstantSize: [(String, [JSONValue])] = [
        ("stack.set_master_count", [.number(2)]),
        ("stack.set_stack_position", [.string("right")]),
        ("bsp.set_strategy", [.string("longest_side")]),
        ("scroll.set_anchor", [.string("center")]),
        (
            "stack.set_master_count_override",
            [.string("1"), .number(2)]
        ),
        (
            "bsp.set_strategy_override",
            [.string("1"), .string("longest_side")]
        ),
    ]

    @Test("A ratio-like write promises every window is spring-sized")
    func ratioWritesPromise() {
        for (command, args) in Self.springSized {
            let core = makeTestCore()
            let response = core.execute(command, args: args)
            #expect(
                response.isSuccess,
                Comment(rawValue: "\(command) did not dispatch")
            )
            #expect(
                core.commandSizing == .allSpringSized,
                Comment(
                    rawValue: "\(command) forgot to raise the "
                        + "sizing promise beside its write"
                )
            )
        }
    }

    @Test("A slot-reassigning command promises nothing")
    func slotWritesDoNotPromise() {
        for (command, args) in Self.mayInstantSize {
            let core = makeTestCore()
            let response = core.execute(command, args: args)
            #expect(
                response.isSuccess,
                Comment(rawValue: "\(command) did not dispatch")
            )
            #expect(
                core.commandSizing == .mayInstantSize,
                Comment(
                    rawValue: "\(command) reassigns slots and "
                        + "must keep the #45 first-frame snap"
                )
            )
        }
    }

    /// The entry reset, which is what keeps the promise from
    /// outliving its dispatch. A command that *fails* returns
    /// before the trailing retile, so a consume-only reset would
    /// leave the flag raised and animate the NEXT dispatch — an
    /// unrelated `set_mode` — as a resize.
    @Test("A failed command cannot leave the promise raised")
    func failureClearsThePromise() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "bsp.set_ratio_h",
                args: [.number(0.6)]
            ).isSuccess
        )
        #expect(core.commandSizing == .allSpringSized)
        // Garbage argument: parses nothing, returns .fail, never
        // reaches the retile.
        #expect(
            !core.execute(
                "stack.set_master_count",
                args: [.string("nonsense")]
            ).isSuccess
        )
        #expect(core.commandSizing == .mayInstantSize)
    }
}
