import Foundation

/// The GUI test target's one spawn of a repo script — Core's
/// `ScriptFixture` is out of this target's reach. A stateless
/// primitive: no setup, no assertions. `MachineTouchTests`
/// admits it by name beside that fixture.
enum GuiScriptFixture {
    struct Run {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    /// `python3 <arguments>`, both pipes drained before the wait
    /// as `ScriptFixture` drains them.
    static func python(_ arguments: [String]) throws -> Run {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3"] + arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(
            status: process.terminationStatus,
            stdout: String(decoding: stdout, as: UTF8.self),
            stderr: String(decoding: stderr, as: UTF8.self)
        )
    }
}
