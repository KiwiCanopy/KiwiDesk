import Testing

@testable import KiwiDeskCore

/// Which keys still fire an either-side row beside sided rows of its
/// chord (#3256), asked of the routers that fire it: one side taken
/// is the intended precedence and no conflict; both taken is a dead
/// row and a counted conflict.
@Suite("Side reach of an either-side row (#3256)")
struct SideReachTests {
    private func row(_ id: String, _ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: "print(\"\(id)\")")
    }

    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    private func reach(
        _ binding: KeyBinding,
        _ rows: [KeyBinding],
        sides: Bool = true
    ) -> SideReach? {
        KeybindingConflicts.sideReach(
            for: binding,
            in: rows,
            distinguishingSides: sides
        )
    }

    @Test("a sided double tap keeps its side; the either-side row the rest")
    func doubleTapNarrows() throws {
        let either = row("e", "cmd+cmd")
        let left = row("l", "lcmd+lcmd")
        let reach = try #require(reach(either, [either, left]))
        #expect(!reach.isDead)
        #expect(reach.runs == (try combo("rcmd+rcmd")))
        #expect(reach.takenBy?.combo == (try combo("lcmd+lcmd")))
        #expect(reach.takenBy?.by == left)
        // A tap reads its side whatever the switch.
        #expect(self.reach(either, [either, left], sides: false) != nil)
        // The sided row and an un-narrowed row have none.
        #expect(self.reach(left, [either, left]) == nil)
        #expect(self.reach(either, [either]) == nil)
    }

    @Test("both sides taken: dead, and a counted conflict")
    func bothSidesTaken() throws {
        let either = row("e", "cmd+cmd")
        let left = row("l", "lcmd+lcmd")
        let right = row("r", "rcmd+rcmd")
        let rows = [either, left, right]
        let reach = try #require(reach(either, rows))
        #expect(reach.isDead)
        #expect(reach.runs == nil)
        #expect(reach.takenBy == nil)
        #expect(Set(reach.taken.map(\.by.id)) == [left.id, right.id])
        let conflict = KeybindingConflicts.conflict(
            for: either,
            in: rows,
            distinguishingSides: true
        )
        #expect(conflict?.target == .sidesTaken([left, right]))
        // The layer pass agrees, and the aggregate counts it.
        let byRow = KeybindingConflicts.rowConflicts(
            of: rows,
            distinguishingSides: true
        )
        #expect(byRow[either.id]?.target == .sidesTaken([left, right]))
        // One side taken stays no conflict.
        #expect(
            KeybindingConflicts.conflict(
                for: either,
                in: [either, left],
                distinguishingSides: true
            ) == nil
        )
    }

    /// A sided chord with the switch on narrows the same way, through
    /// the same predicate; off, Carbon reads it either-side and the
    /// pair is a side collapse instead.
    @Test("a sided chord narrows while sides are told apart")
    func chordNarrows() throws {
        let either = row("e", "cmd+h")
        let right = row("r", "rcmd+h")
        let reach = try #require(reach(either, [either, right]))
        #expect(reach.runs == (try combo("lcmd+h")))
        #expect(reach.takenBy?.combo == (try combo("rcmd+h")))
        #expect(self.reach(either, [either, right], sides: false) == nil)
    }

    /// Two open modifiers: the forms a sided row takes spell one combo,
    /// and so do the ones still answered.
    @Test("a two-modifier chord spells what it keeps")
    func twoModifiers() throws {
        let either = row("e", "cmd+opt+h")
        let right = row("r", "rcmd+opt+h")
        let reach = try #require(reach(either, [either, right]))
        #expect(reach.answered.count == 2)
        #expect(reach.runs == (try combo("lcmd+opt+h")))
        #expect(reach.takenBy?.combo == (try combo("rcmd+opt+h")))
    }

    /// A key sequence's tap leader rides the tap router, so it
    /// narrows as a tap row does.
    @Test("a sided tap leader narrows an either-side tap")
    func leaderNarrows() throws {
        let either = row("e", "cmd+cmd")
        let leader = KeyBinding(combo: "rcmd+rcmd", kind: .sequence)
        let reach = try #require(reach(either, [either, leader]))
        #expect(reach.runs == (try combo("lcmd+lcmd")))
        #expect(reach.takenBy?.by == leader)
    }

    /// A sided chord leader is asked first, as `.sequences` is, so
    /// it narrows an either-side chord row (#3278).
    @Test("a sided chord leader narrows an either-side chord")
    func chordLeaderNarrows() throws {
        let either = row("e", "cmd+h")
        let leader = KeyBinding(combo: "lcmd+h", kind: .sequence)
        let reach = try #require(reach(either, [either, leader]))
        #expect(reach.runs == (try combo("rcmd+h")))
        #expect(reach.takenBy?.combo == (try combo("lcmd+h")))
        #expect(reach.takenBy?.by == leader)
        #expect(self.reach(either, [either, leader], sides: false) == nil)
    }

    /// A leader outranks a sided press row on its other side, and a
    /// sided leader narrows an either-side leader as rows do.
    @Test("a leader is judged and outranks a sided row")
    func leaderIsJudged() throws {
        let open = KeyBinding(combo: "cmd+j", kind: .sequence)
        let pressed = row("p", "lcmd+j")
        #expect(reach(open, [open, pressed]) == nil)
        // The leader takes the sided row's one form: it never fires,
        // a plain clash with that leader.
        let shadowed = try #require(reach(pressed, [open, pressed]))
        #expect(shadowed.isDead)
        #expect(shadowed.takers == [open])
        #expect(
            KeybindingConflicts.conflict(
                for: pressed,
                in: [open, pressed],
                distinguishingSides: true
            )?.target == .otherBinding(open)
        )
        let sided = KeyBinding(combo: "rcmd+j", kind: .sequence)
        let reach = try #require(reach(open, [open, sided]))
        #expect(reach.runs == (try combo("lcmd+j")))
        #expect(reach.takenBy?.by == sided)
    }

    /// One either-side leader taking both forms of a two-modifier
    /// row is one taker: a plain clash, never "one side each".
    @Test("one row taking every form is a plain clash")
    func oneTakerIsAClash() throws {
        let either = row("e", "cmd+ropt+h")
        let leader = KeyBinding(combo: "cmd+opt+h", kind: .sequence)
        let reach = try #require(reach(either, [either, leader]))
        #expect(reach.isDead)
        #expect(
            KeybindingConflicts.conflict(
                for: either,
                in: [either, leader],
                distinguishingSides: true
            )?.target == .otherBinding(leader)
        )
    }

    /// A Hyper row is Carbon's, which reads it either-side: no row
    /// narrows it, and it narrows none.
    @Test("a Hyper row has no reach")
    func hyperHasNone() {
        let either = row("e", "hyper+cmd+h")
        let left = row("l", "hyper+lcmd+h")
        #expect(reach(either, [either, left]) == nil)
        #expect(reach(left, [either, left]) == nil)
    }

    /// Two leaders naming each side take every key from the chord
    /// row: dead, and a counted conflict.
    @Test("two sided chord leaders: dead, and a counted conflict")
    func leadersTakeBothSides() throws {
        let either = row("e", "cmd+h")
        let left = KeyBinding(combo: "lcmd+h", kind: .sequence)
        let right = KeyBinding(combo: "rcmd+h", kind: .sequence)
        let rows = [either, left, right]
        let reach = try #require(reach(either, rows))
        #expect(reach.isDead)
        #expect(Set(reach.takers.map(\.id)) == [left.id, right.id])
        let conflict = KeybindingConflicts.conflict(
            for: either,
            in: rows,
            distinguishingSides: true
        )
        #expect(conflict?.target == .sidesTaken([left, right]))
        let byRow = KeybindingConflicts.rowConflicts(
            of: rows,
            distinguishingSides: true
        )
        #expect(byRow[either.id]?.target == .sidesTaken([left, right]))
    }

    /// The layer pass the page reads answers what the per-row door
    /// answers, row by row (#3256).
    @Test("the layer pass matches the per-row reach")
    func layerMatchesRowByRow() {
        let rows = [
            row("a", "cmd+cmd"), row("b", "lcmd+lcmd"),
            row("c", "cmd+h"), row("d", "rcmd+h"),
            row("e", "opt+opt"), row("f", "lopt+lopt"),
            row("g", "ropt+ropt"), row("h", "ctrl+k"),
            KeyBinding(combo: "lcmd+j", kind: .sequence),
            row("i", "cmd+j"),
            KeyBinding(combo: "lopt+m", kind: .sequence),
            KeyBinding(combo: "ropt+m", kind: .sequence),
            row("j", "opt+m"),
        ]
        for sides in [true, false] {
            let layer = KeybindingConflicts.rowReaches(
                of: rows,
                distinguishingSides: sides
            )
            #expect(!layer.isEmpty)
            for binding in rows {
                #expect(
                    layer[binding.id]
                        == reach(binding, rows, sides: sides),
                    "\(binding.combo) sides \(sides)"
                )
            }
        }
    }

    /// Forms another row takes in more than one combo, or several
    /// rows taking forms, spell no single caption.
    @Test("a reach that needs two combos to say spells none")
    func unspelled() throws {
        let either = row("e", "cmd+opt+h")
        let a = row("a", "lcmd+lopt+h")
        let b = row("b", "rcmd+ropt+h")
        let reach = try #require(reach(either, [either, a, b]))
        #expect(!reach.isDead)
        #expect(reach.takenBy == nil)
        // The two forms still answered are diagonal: no one combo.
        #expect(reach.answered.count == 2)
        #expect(reach.runs == nil)
        #expect(Set(reach.takers.map(\.id)) == [a.id, b.id])
    }

    /// Two rows taking forms that spell one combo still caption no
    /// one row: the caption names a single holder.
    @Test("two rows taking one combo's forms name no holder")
    func twoTakersOneCombo() throws {
        let either = row("e", "cmd+opt+h")
        let a = row("a", "lcmd+lopt+h")
        let b = row("b", "lcmd+ropt+h")
        let reach = try #require(reach(either, [either, a, b]))
        #expect(reach.runs == (try combo("rcmd+opt+h")))
        #expect(reach.takenBy == nil)
        #expect(reach.takers.map(\.id) == [a.id, b.id])
    }

    /// Both sides taken outranks a macOS shortcut on the chord: the
    /// row never reaches macOS either.
    @Test("a dead reach reads before a system shortcut")
    func deadBeforeSystem() {
        let either = row("e", "cmd+space")
        let rows = [either, row("l", "lcmd+space"), row("r", "rcmd+space")]
        let conflict = KeybindingConflicts.conflict(
            for: either,
            in: rows,
            distinguishingSides: true
        )
        guard case .sidesTaken = conflict?.target else {
            Issue.record(
                "expected sidesTaken, got \(String(describing: conflict))"
            )
            return
        }
    }
}
