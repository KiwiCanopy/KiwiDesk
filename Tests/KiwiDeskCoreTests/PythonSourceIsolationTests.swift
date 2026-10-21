import Foundation
import Testing

/// A Python source a test runs sits alone in its directory
/// (#2518). Python puts the script's own directory first on
/// `sys.path` and lists it on every import, so a script written
/// into a shared temp dir pays for every entry beside it — 15 s
/// for two lines once that dir held 1.3 M entries, and the
/// localization suites blocked the cooperative pool behind it.
@Suite("Python sources run from their own directory")
struct PythonSourceIsolationTests {
    @Test("the script's directory holds only the script")
    func directoryHoldsOnlyTheScript() throws {
        let run = try runPythonSource(
            """
            import json, os, sys
            print(sys.path[0])
            print(json.dumps(sorted(os.listdir(sys.path[0]))))
            """,
            arguments: []
        )
        #expect(run.status == 0, "\(run.stderr)")
        let lines = run.stdout.split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        #expect(lines.last == #"["script.py"]"#)
        // And it is gone once the run returns.
        if let directory = lines.first {
            #expect(!FileManager.default.fileExists(atPath: directory))
        }
    }
}
