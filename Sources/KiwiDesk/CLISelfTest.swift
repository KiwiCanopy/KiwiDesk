import Foundation
import KiwiDeskCore

/// The terminal rendering of `self_test`'s reply (#1889): one
/// block per home, a verdict column, and a closing tally. JSON
/// stays the piped answer; this only reads it.
enum CLISelfTest {
    /// True for `--json`, false for nothing; nil for anything
    /// else, which is an error rather than a silent no-op.
    static func parseOptions(_ options: [String]) -> Bool? {
        switch options {
        case []: return false
        case ["--json"]: return true
        default: return nil
        }
    }

    /// 2 when any path `failed` — distinct from an error's 1 —
    /// else 0: absent, resolved and inconclusive are reports, not
    /// failures. Read from `counts`, text and `--json` alike.
    static func exitCode(_ data: JSONValue?) -> Int32 {
        guard case .object(let reply)? = data,
            case .object(let counts)? = reply["counts"],
            case .number(let failed)? = counts["failed"]
        else { return 0 }
        return failed > 0 ? 2 : 0
    }

    /// Nil when `data` is not the `self_test` shape.
    static func render(_ data: JSONValue) -> String? {
        guard case .object(let reply) = data,
            case .array(let probes)? = reply["probes"]
        else { return nil }
        let rows = probes.compactMap(row)
        guard rows.count == probes.count else { return nil }
        let nameWidth = rows.map(\.name.count).max() ?? 0
        let verdictWidth =
            PrivatePathVerdict.labels.map(\.count).max() ?? 0
        var lines: [String] = []
        if let macOS = reply["macos"]?.stringValue {
            lines.append("macOS \(macOS)")
        }
        var home: String?
        for row in rows {
            if row.home != home {
                lines.append("")
                lines.append(row.home)
                home = row.home
            }
            lines.append(
                "  " + pad(row.verdict, verdictWidth) + "  "
                    + pad(row.name, nameWidth) + "  " + row.detail
            )
        }
        lines.append("")
        lines.append(tally(reply["counts"]))
        return lines.joined(separator: "\n")
    }

    private struct Row {
        let name: String
        let home: String
        let verdict: String
        let detail: String
    }

    private static func row(_ value: JSONValue) -> Row? {
        guard case .object(let fields) = value,
            let name = fields["name"]?.stringValue,
            let home = fields["home"]?.stringValue,
            let verdict = fields["verdict"]?.stringValue
        else { return nil }
        return Row(
            name: name,
            home: home,
            verdict: verdict,
            detail: fields["detail"]?.stringValue ?? ""
        )
    }

    private static func tally(_ counts: JSONValue?) -> String {
        guard case .object(let fields)? = counts else { return "" }
        return PrivatePathVerdict.labels.map { label in
            let count: Int
            if case .number(let n)? = fields[label] {
                count = Int(n)
            } else {
                count = 0
            }
            return "\(count) \(label)"
        }.joined(separator: ", ")
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(
            toLength: max(width, text.count),
            withPad: " ",
            startingAt: 0
        )
    }
}
