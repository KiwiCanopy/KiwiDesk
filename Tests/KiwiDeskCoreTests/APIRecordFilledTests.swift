import Foundation
import Testing

@testable import KiwiDeskCore

/// Every command in KiwiDesk describes itself (#1033).
///
/// This suite was a ratchet while #1033 was in two halves: it
/// pinned how many records were still placeholders, in both
/// directions, so filling a group was a deliberate step and
/// un-filling one was caught. With the surface complete the
/// ratchet is gone and the invariant is the plain one — a
/// command whose record carries no prose reds here.
///
/// It is deliberately ONE test. The earlier per-group clauses —
/// the exemplar groups, the Lua-only entries, the named Desktop
/// verbs — were subsets that could not fail without this one
/// failing first, which `tests.md` does not owe a second test
/// at another altitude. What they were for (keeping the worked
/// examples worked while most records were placeholders) ended
/// when the last placeholder did.
@Suite("API record completeness")
struct APIRecordFilledTests {
    @Test("every API record is written")
    func noRecordIsPending() {
        // Reads the whole listing rather than the record tables,
        // so a command whose record is MISSING is caught too:
        // `APIReference.coreEntries` falls back to a pending
        // record rather than dropping the command, and that
        // fallback surfaces here.
        let entries = APIReference.entries
        let reach =
            "only \(entries.count) entries; the surface is not "
            + "being read"
        #expect(entries.count > 200, "\(reach)")
        let pending =
            entries
            .filter(\.record.isPending)
            .map(\.qualifiedName)
            .sorted()
        let head = pending.prefix(12).joined(separator: ", ")
        let message =
            "\(pending.count) record(s) are pending; every command "
            + "must have a written summary. Missing: \(head)"
        #expect(pending.isEmpty, "\(message)")
    }
}
