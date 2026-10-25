import Foundation
import Testing

@testable import KiwiDeskCore

/// The kind register (#2610): every entry's kind is read from its
/// name, and `APIReference.kindExceptions` hand-keeps the names
/// that misread. A row naming no entry, or one its name already
/// reads right, is dead weight that hides the next real exception.
///
/// No guard can read what a verb does, so the net for a NEW misread
/// is the name, as `APIDestructiveCensusTests`' is: a command whose
/// first word is one that reads either way is an exception or ruled
/// to keep its derived kind below. A misread named otherwise is
/// review's (core-boundaries.md).
@Suite("API kind register")
struct APIKindCensusTests {
    /// First words that do not say whether a verb acts, sets or
    /// asks.
    static let ambiguousVerbs = [
        "explain", "describe", "enable", "disable", "define",
        "declare", "bind", "unbind", "on", "pin", "unpin", "save",
        "load", "delete", "remove", "apply", "keep", "revert",
        "subscribe", "self", "help", "version", "debug", "override",
        "fit", "reset", "create", "register", "show", "hide",
    ]

    /// Commands the net catches that keep their derived kind, each
    /// with its reason.
    static let ruledDerived: [String: String] = [
        "debug_log": "writes a line to the log, settles nothing "
            + "(owner, #2610)",
        "save_profile": "a key that saves the arrangement acts "
            + "(owner, #2610)",
        "load_profile": "switching arrangement is the act a key "
            + "runs (owner, #2610)",
        "delete_profile": "kept beside save and load (owner, #2610)",
        "create_space": "the session scope is the default "
            + "(architect, #2610)",
        "delete_space": "the session scope is the default "
            + "(architect, #2610)",
        "override_sticky_reach": "a live per-window override, "
            + "beside make_sticky (architect, #2610)",
        "reset_layout_sizing": "clears session sizing, as a resize "
            + "press writes it (#764)",
        "kiwihub.show": "opens a panel",
    ]

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

    @Test("each kind is used")
    func everyKindIsUsed() {
        let kinds = APIReference.entries.map(APIReference.kind(of:))
        #expect(Set(kinds) == Set(APIKind.allCases))
    }

    @Test("a name that reads either way is ruled")
    func ambiguousNamesAreRuled() {
        #expect(!APIReference.entries.isEmpty)
        for entry in APIReference.entries {
            let name = entry.name
            guard
                Self.ambiguousVerbs.contains(where: {
                    name == $0 || name.hasPrefix($0 + "_")
                })
            else { continue }
            let qualified = entry.qualifiedName
            let message =
                "\(qualified) may misread its kind: add it to "
                + "APIReference.kindExceptions or rule it here"
            #expect(
                APIReference.kindExceptions[qualified] != nil
                    || Self.ruledDerived[qualified] != nil,
                "\(message)"
            )
        }
    }

    @Test("ruled names are entries outside the exceptions")
    func ruledDerivedIsDisjoint() {
        for name in Self.ruledDerived.keys {
            #expect(APIReference.entry(named: name) != nil, "\(name)")
            #expect(APIReference.kindExceptions[name] == nil, "\(name)")
        }
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
