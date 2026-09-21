import Foundation

/// The destination-title half of the interpolated-label scan
/// (#818), split from `SourceScan+InterpolatedLabels.swift` at
/// the §2.1 ceiling when #1117 added the label-slot derivation.
extension SourceScan {
    /// `SettingsDestination.<case>.title` → the key that case
    /// returns, parsed from the one file that owns the switch.
    ///
    /// A destination title is the label five-plus frames name,
    /// and it is reached through a property rather than an
    /// inline `L(` precisely so the English is authored once.
    /// Without this, every one of those frames is invisible to
    /// the scan and gets no floor — and the alternative,
    /// reshaping the call sites to inline `L(`, would paste the
    /// same English at five sites to please a test. So the scan
    /// learns the one accessor shape it can resolve from source.
    ///
    /// The case name is NOT derivable from the key
    /// (`.layoutDefaults` returns `destination.layout`), so the
    /// pairing is read out of the switch rather than guessed.
    static func destinationTitleKeys() throws
        -> [String: String]
    {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources")
                    .appendingPathComponent("KiwiDesk")
                    .appendingPathComponent("Settings")
                    .appendingPathComponent(
                        "SettingsDestination.swift"
                    ),
                encoding: .utf8
            )
        )
        // Scanned over the WHOLE source, not line by line: a
        // case's `L(` and its key literal need not share a line,
        // and `.advancedColors` is exactly that shape. The
        // line-scoped first cut missed it, silently — the frame
        // naming that destination simply went undiscovered and
        // lost its floor, which is how a fail-open parser hurts.
        var pairs: [String: String] = [:]
        var pending: String?
        var index = source.startIndex
        while index < source.endIndex {
            let rest = source[index...]
            if rest.hasPrefix("case ."),
                let colon = rest.firstIndex(of: ":")
            {
                let name = rest[
                    rest.index(rest.startIndex, offsetBy: 6)..<colon
                ]
                if name.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    pending = String(name)
                }
            }
            if let name = pending, rest.hasPrefix("L(") {
                if let open = rest.firstIndex(of: "\""),
                    let close = rest[
                        rest.index(after: open)...
                    ].firstIndex(of: "\"")
                {
                    let key = String(
                        rest[rest.index(after: open)..<close]
                    )
                    if key.hasPrefix("destination.") {
                        pairs[name] = key
                        pending = nil
                    }
                }
            }
            index = source.index(after: index)
        }
        return pairs
    }
}
