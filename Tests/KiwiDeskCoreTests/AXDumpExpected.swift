@testable import KiwiDeskCore

/// What KiwiDesk decides of each recorded dump (#1883): detection's
/// verdict, the ignore gate's, and the shadow rule's reading — nil
/// where the dump lacks a fact that rule reads.
///
/// FROZEN from the classifier as it stood when the corpus landed:
/// a row here is today's behaviour, not a ruling that it is right.
/// Changing one is a ruling on that app, made in its own change,
/// never to turn this suite green. Written by KiwiDesk alone —
/// AeroSpace's own verdicts in the dumps are never read.
enum AXDumpExpected {
    struct Row {
        /// The dump's path below `AXDumps/`, without `.json5`.
        let name: String
        let verdict: DumpVerdict

        static func row(
            _ name: String,
            _ detection: FloatVerdict?,
            _ admission: DumpAdmission?,
            _ shell: ShellReading?
        ) -> Row {
            Row(
                name: name,
                verdict: DumpVerdict(
                    detection: detection,
                    admission: admission,
                    shell: shell
                )
            )
        }
    }

    static var all: [Row] { rowsAToF + rowsGToN + rowsOToZ }
}
