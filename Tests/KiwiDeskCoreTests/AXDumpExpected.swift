@testable import KiwiDeskCore

/// What KiwiDesk decides of each recorded dump (#1883): detection's
/// verdict, the ignore gate's, and the shadow rule's reading — nil
/// where the dump lacks a fact that rule reads.
///
/// Every row carries where its verdict came from. A `.frozen` row
/// is the classifier as it stood when the corpus landed: today's
/// behaviour, not a ruling that it is right. Changing a row is a
/// ruling on that app, made in its own change, which turns the row
/// `.ruled` with the issue that decided it — never an edit to make
/// this suite pass. Written by KiwiDesk alone: AeroSpace's own
/// verdicts in the dumps are never read.
enum AXDumpExpected {
    enum Provenance: Equatable {
        /// Today's verdict, recorded unjudged.
        case frozen
        /// A verdict the owner ruled on, in this issue.
        case ruled(issue: Int)
    }

    struct Row {
        /// The dump's path below `AXDumps/`, without `.json5`.
        let name: String
        let verdict: DumpVerdict
        let provenance: Provenance

        static func row(
            _ name: String,
            _ detection: FloatVerdict?,
            _ admission: DumpAdmission?,
            _ shell: ShellReading?,
            _ provenance: Provenance = .frozen
        ) -> Row {
            Row(
                name: name,
                verdict: DumpVerdict(
                    detection: detection,
                    admission: admission,
                    shell: shell
                ),
                provenance: provenance
            )
        }
    }

    static var all: [Row] { rowsAToF + rowsGToN + rowsOToZ }
}
