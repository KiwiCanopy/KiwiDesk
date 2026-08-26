import Foundation
import Testing

@testable import KiwiDeskCore

/// Guards that every command in KiwiDesk is fully described (#1033).
///
/// Every record across the whole API surface has its prose written
/// and its arguments declared. Adding a command without adding its
/// record, or adding a record without prose, reds this suite.
@Suite("API record completeness")
struct APIRecordFilledTests {
    /// The groups part 1 filled as worked examples. Part 2 reads
    /// these for the pattern, so a regression here would take
    /// the pattern with it.
    static let exemplarGroups = ["scroll", "app_bar"]

    @Test("every API record is written")
    func noRecordIsPending() {
        let pending = APIReference.entries
            .filter(\.record.isPending)
            .map(\.qualifiedName)
            .sorted()
        let head = pending.prefix(12).joined(separator: ", ")
        let message =
            "\(pending.count) record(s) are pending; every command "
            + "must have a written summary. Missing: \(head)"
        #expect(pending.isEmpty, "\(message)")
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
