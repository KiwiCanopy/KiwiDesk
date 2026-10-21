import Foundation

/// `+Source`: an inline Python source rather than a repo script,
/// run from a fresh directory holding only it and removed after
/// (#2518). Python puts a script's own directory
/// first on `sys.path` and lists it on every import, so a script
/// written into a shared temp dir pays for every entry beside it
/// — 15 s for two lines once that dir held 1.3 M entries.
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
