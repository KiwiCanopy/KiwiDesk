import Foundation
import Testing

@testable import KiwiDeskCore

/// Shared reflection helpers for the field-list parity guards
/// (AGENTS.md §5, `.claude/rules/parity-tests.md`). These let a
/// parity test discover a struct's fields *structurally* instead
/// of hand-listing them, so adding a field to one side of a
/// mirror turns a forgotten sibling into a red build rather than
/// silent data loss.

/// Stored-property names of `value`, via `Mirror`.
func fieldNames(_ value: Any) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap(\.label))
}

/// Field name → `String(describing:)` of its value. String
/// descriptions compare cleanly across the value types these
/// structs use (numbers, strings, raw-value enums, optionals).
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
