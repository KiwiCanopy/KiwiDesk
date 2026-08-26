import Foundation
import KiwiDeskCore

/// Renders a command response's payload for stdout.
///
/// Split out of `runSocketCommand` so the formatting decision is
/// testable without a live socket: the CLI half is one `print`,
/// and everything that decides *what* gets printed is here.
enum CLIOutput {
    /// Encodes `data` the way the CLI prints it.
    ///
    /// `.sortedKeys` is unconditional. Without it `JSONEncoder`
    /// emits dictionary keys in `Dictionary` hash order, so two
    /// sibling objects inside ONE response can disagree on key
    /// order and a re-run can disagree with itself — which is
    /// what #1034 reported from `list_monitors`. Sorting costs
    /// nothing and makes a captured response diffable.
    ///
    /// `.prettyPrinted` is the caller's to decide, because it
    /// is the half that changes shape: a piped or redirected
    /// call must keep the compact single line that existing
    /// scripts already parse, and only a terminal gets the
    /// indented form.
    ///
    /// Returns nil when the payload cannot be encoded, which is
    /// the same silent-skip the call site had before — a
    /// `JSONValue` is schema-free and has no unencodable case,
    /// so this is unreachable rather than a swallowed error.
    static func render(
        _ data: JSONValue,
        pretty: Bool
    ) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        guard let encoded = try? encoder.encode(data) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }

    /// Whether stdout is a terminal rather than a pipe or file.
    ///
    /// The one input to the `pretty` decision, named here so a
    /// test can drive `render` without owning the process's
    /// file descriptors.
    static var stdoutIsTerminal: Bool {
        isatty(FileHandle.standardOutput.fileDescriptor) == 1
    }
}
