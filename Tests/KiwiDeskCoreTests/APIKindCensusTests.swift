import Foundation
import Testing

@testable import KiwiDeskCore

/// The kind register (#2610): every entry's kind is read from its
/// name, and `APIReference.kindExceptions` hand-keeps the names
/// that misread. A row naming no entry, or one its name already
/// reads right, is dead weight that hides the next real exception.
@Suite("API kind register")
struct APIKindCensusTests {
    @Test("the name reads the kind")
    func derivation() {
        #expect(APIReference.derivedKind(of: "set_gaps") == .setting)
        #expect(APIReference.derivedKind(of: "get_state") == .query)
        #expect(APIReference.derivedKind(of: "list") == .query)
        #expect(APIReference.derivedKind(of: "list_groups") == .query)
        #expect(APIReference.derivedKind(of: "current") == .query)
        #expect(APIReference.derivedKind(of: "focus") == .action)
        // A prefix is a whole word, never a stem.
        #expect(APIReference.derivedKind(of: "settle") == .action)
        #expect(APIReference.derivedKind(of: "listen") == .action)
    }

    @Test("every entry resolves to a kind, each kind is used")
    func everyEntryResolves() {
        let kinds = APIReference.entries.map(APIReference.kind(of:))
        #expect(kinds.count == APIReference.entries.count)
        #expect(Set(kinds) == Set(APIKind.allCases))
    }

    @Test("every exception names an entry")
    func exceptionsNameEntries() {
        for name in APIReference.kindExceptions.keys {
            #expect(
                APIReference.entry(named: name)?.qualifiedName == name,
                "\(name) is a kind exception but no entry"
            )
        }
    }

    @Test("every exception differs from what its name reads")
    func exceptionsAreNeeded() {
        for (name, kind) in APIReference.kindExceptions {
            guard let entry = APIReference.entry(named: name) else {
                continue
            }
            let message =
                "\(name) reads \(kind.rawValue) by its name; "
                + "drop its exception row"
            #expect(
                APIReference.derivedKind(of: entry.name) != kind,
                "\(message)"
            )
            #expect(APIReference.kind(of: entry) == kind)
        }
    }

    @Test("the listing carries the kind and filters by it")
    func listingCarriesTheKind() throws {
        let one = APIReference.helpResponse(for: "set_mode")
        guard case .object(let entry)? = one.data else {
            Issue.record("expected an object payload")
            return
        }
        #expect(entry["kind"] == .string("action"))
        for kind in APIKind.allCases {
            let listing = APIReference.helpResponse(kind: kind)
            guard case .object(let root)? = listing.data,
                case .array(let groups)? = root["groups"]
            else {
                Issue.record("expected a grouped listing")
                return
            }
            #expect(!groups.isEmpty)
            for case .object(let group) in groups {
                guard case .array(let rows)? = group["commands"] else {
                    Issue.record("expected commands")
                    continue
                }
                #expect(!rows.isEmpty)
                for case .object(let row) in rows {
                    #expect(row["kind"] == .string(kind.rawValue))
                }
            }
        }
    }
}
