import Foundation
import Testing

@testable import KiwiDeskCore

/// Shared reflection helpers for the field-list parity guards
/// (AGENTS.md §5, `.claude/rules/parity-tests.md`). These let a
/// parity test discover a struct's fields *structurally* instead
/// of hand-listing them, so adding a field to one side of a
/// mirror turns a forgotten sibling into a red build rather than
/// silent data loss.
///
/// Convention note: `.claude/rules/tests.md` prefers per-file
/// private helpers ("no shared test harness"). This file is a
/// deliberate, ratified exception — these are stateless, generic
/// *test primitives* (pure reflection mechanics, no setup/teardown
/// coupling), and a single copy is *safer* than duplication here:
/// a divergent copy of `snakeCased`/`expectAllChanged` could
/// silently weaken one guard, which is the exact failure mode #73
/// exists to prevent.

/// Stored-property names of `value`, via `Mirror`.
func fieldNames(_ value: Any) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap(\.label))
}

/// Field name → `String(describing:)` of its value. A heuristic,
/// not true value equality (`Mirror` children are `Any`, not
/// `Equatable`): string descriptions compare cleanly across the
/// value types these structs use (numbers, strings, raw-value
/// enums, optionals). Only ever used as an *exhaustiveness* or
/// *changed?* net that fails red — real data survival is always
/// proven separately by an `Equatable` round-trip.
func fieldValues(_ value: Any) -> [String: String] {
    Mirror(reflecting: value).children.reduce(
        into: [String: String]()
    ) { acc, child in
        if let label = child.label {
            acc[label] = String(describing: child.value)
        }
    }
}

/// JSON spellings (`stringValue`) of a `CodingKey` set — for
/// comparing keys against the snake_cased field names.
func keyStrings<K: CodingKey>(_ keys: [K]) -> Set<String> {
    Set(keys.map(\.stringValue))
}

/// camelCase → snake_case, matching the project's CodingKey
/// convention (`activeStyle` → `active_style`). Comparing field
/// names through this also pins the "one vocabulary" rule
/// (AGENTS.md §5) that JSON keys stay snake_case.
///
/// Deliberately *naive* — it only inserts `_` before an uppercase
/// letter (no acronym/digit handling). That is safe: a field
/// whose key needs more than naive snake_case makes this test
/// fail **red**, never silently, and is a signal to reconsider
/// the key (or add an explicit exception), not to complicate
/// this helper.
func snakeCased(_ name: String) -> String {
    name.reduce(into: "") { out, character in
        if character.isUppercase {
            out += "_" + character.lowercased()
        } else {
            out.append(character)
        }
    }
}

/// Fields whose value differs between `value` and `base`.
func changedFields<T>(_ value: T, from base: T) -> Set<String> {
    let now = fieldValues(value)
    let was = fieldValues(base)
    return Set(now.filter { $0.value != was[$0.key] }.map(\.key))
}

/// Asserts a fixture touches *every* field: each differs from the
/// default `base`. This is what makes a hand-built round-trip
/// fixture forget-proof — a new field left unset (still default)
/// turns this red, forcing the fixture to cover it.
func expectAllChanged<T>(
    _ value: T,
    from base: T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let baseValues = fieldValues(base)
    for (field, current) in fieldValues(value) {
        #expect(
            current != baseValues[field],
            "fixture leaves \(field) at its default value",
            sourceLocation: sourceLocation
        )
    }
}

/// The forget-proof pair for a manual sparse `Codable`: the
/// exhaustiveness net (`expectAllChanged`) forces `fixture` to
/// touch every field, then a real `Equatable` round-trip proves
/// each survives decode ↔ encode ↔ CodingKeys. A field left unset
/// trips the first; a forgotten Codable line trips the second.
func expectRoundTrips<T: Codable & Equatable>(
    _ fixture: T,
    from base: T,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    expectAllChanged(fixture, from: base, sourceLocation: sourceLocation)
    let data = try JSONEncoder().encode(fixture)
    let back = try JSONDecoder().decode(T.self, from: data)
    #expect(back == fixture, sourceLocation: sourceLocation)
}

/// Forget-proof net for a per-field `resolved(onto:)`/`resolved
/// (with:)` merge: `resolved` must differ from `base` on every
/// field the override actually covers, so a forgotten `if let`
/// (which leaves that field at the base value) goes red. `covered`
/// is the override's own field-name set; the caller resolves an
/// all-set override onto a `base` whose covered fields all differ.
func expectResolvesEveryField<P>(
    resolved: P,
    base: P,
    covered: Set<String>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let baseValues = fieldValues(base)
    for (field, value) in fieldValues(resolved)
    where covered.contains(field) {
        #expect(
            value != baseValues[field],
            "resolved() left \(field) at the base value",
            sourceLocation: sourceLocation
        )
    }
}
