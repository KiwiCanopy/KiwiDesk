import Foundation

/// `+Source`: an inline Python source rather than a repo script,
/// run from a fresh directory holding only it and removed after.
/// Python lists the script's directory on every import (#2518).
@discardableResult
func runPythonSource(
    _ source: String,
    arguments: [String]
) throws -> ScriptRun {
    let directory = testTemporaryDirectory.appendingPathComponent(
        "py-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let script = directory.appendingPathComponent("script.py")
    try source.write(to: script, atomically: false, encoding: .utf8)
    return try runPythonScript(at: script, arguments: arguments)
}
