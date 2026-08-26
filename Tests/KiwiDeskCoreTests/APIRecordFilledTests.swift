import Foundation
import Testing

@testable import KiwiDeskCore

/// How much of the API surface still owes #1033 a summary.
///
/// **This guard is temporary and says so.** #1033 ships in two
/// parts: part 1 built the record type, the derivation, the
/// routing and the exemplar groups; part 2 fills the remaining
/// records against them. Until part 2 lands, the honest state of
/// the tree is "most records are `.todo()`", and a guard that
/// simply refused pending records would be red on every commit
/// in between — so it pins the COUNT instead, which cannot drift
/// unnoticed in either direction:
///
/// - filling records without lowering `pendingRecords` reds,
///   which is the reminder to lower it;
/// - adding a `.todo()` back, or landing a new command with no
///   summary, reds too.
///
/// **When `pendingRecords` reaches zero, this suite's job
/// changes**: delete the constant, assert no record is pending
/// at all, and delete `APIRecord.todo` with its last caller.
/// That is the closing move of #1033, not a follow-up.
@Suite("API record completeness")
struct APIRecordFilledTests {
    /// Records still carrying `APIRecord.pendingSummary`.
    /// Lower this as part 2 fills groups; never raise it.
    static let pendingRecords = 194

    /// The groups part 1 filled as worked examples. Part 2 reads
    /// these for the pattern, so a regression here would take
    /// the pattern with it.
    static let exemplarGroups = ["scroll", "app_bar"]

    @Test("the pending count is exactly what is recorded")
    func pendingCountIsPinned() {
        let pending = APIReference.entries
            .filter(\.record.isPending)
            .map(\.qualifiedName)
            .sorted()
        let head = pending.prefix(12).joined(separator: ", ")
        let message =
            "\(pending.count) records are pending; this guard "
            + "expects \(Self.pendingRecords). Filling records? "
            + "Lower `pendingRecords`. Adding a command? Write "
            + "its summary. Still pending: \(head)…"
        #expect(pending.count == Self.pendingRecords, "\(message)")
    }

    @Test("the exemplar groups are complete")
    func exemplarGroupsAreWritten() {
        for group in Self.exemplarGroups {
            let pending =
                APIReference.groups
                .first { $0.name == group }?
                .entries
                .filter(\.record.isPending)
                .map(\.name) ?? []
            let message =
                "\(group) is an exemplar and must stay written; "
                + "pending: \(pending.sorted())"
            #expect(pending.isEmpty, "\(message)")
        }
    }

    @Test("the Lua-only entry points are complete")
    func luaOnlyIsWritten() {
        // The other exemplar: the only records taking a
        // `.callback` or a `.table`, and the only ones the CLI
        // cannot reach.
        let pending = APIReference.luaOnlyRecords
            .filter { $0.value.isPending }
            .map(\.key)
        #expect(pending.isEmpty, "pending: \(pending.sorted())")
    }

    @Test("the Desktop verbs and create_space are complete")
    func namedCoreExemplarsAreWritten() {
        // The three Desktop verbs are the `.desktop` argument's
        // only home; `create_space` is the surface's one
        // optional argument. Both patterns part 2 needs.
        let exemplars = [
            "focus_desktop", "move_to_desktop",
            "move_to_desktop_and_follow", "create_space",
        ]
        for name in exemplars {
            let record = APIReference.entry(named: name)?.record
            #expect(
                record?.isPending == false,
                "\(name) is an exemplar and must stay written"
            )
        }
    }
}
