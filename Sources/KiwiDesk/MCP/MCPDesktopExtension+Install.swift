import AppKit
import KiwiDeskCore

/// Building the `.mcpb` on disk and handing it to Claude Desktop,
/// which shows its own install dialog (#2258 ▸ Ruling).
extension MCPDesktopExtension {
    static let claudeDesktopBundleID = "com.anthropic.claudefordesktop"

    /// Why a hand-off did not reach Claude Desktop's dialog.
    enum Failure: Error, Equatable {
        /// A translocated copy's path dies at relaunch, so no
        /// extension may carry it (#1685 ▸ Ruling 6a).
        case translocated
        case noClaudeDesktop
        case manifestUnencodable
        case packFailed(Int32)
        /// Claude Desktop refused the file it was handed.
        case openFailed
    }

    /// Claude Desktop's app, when one is installed.
    static func claudeDesktop(
        workspace: NSWorkspace = .shared
    ) -> URL? {
        workspace.urlForApplication(
            withBundleIdentifier: claudeDesktopBundleID
        )
    }

    /// Writes the bundle's files into `directory`: the manifest,
    /// the executable launcher and, when given, the icon.
    static func stage(
        in directory: URL,
        executable: String,
        version: String,
        icon: Data?
    ) throws {
        let files = FileManager.default
        let launcher = directory.appendingPathComponent(launcherPath)
        try files.createDirectory(
            at: launcher.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try manifest(version: version).write(
            to: directory.appendingPathComponent("manifest.json")
        )
        try Data(self.launcher(executable: executable).utf8)
            .write(to: launcher)
        try files.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: launcher.path
        )
        if let icon {
            try icon.write(to: directory.appendingPathComponent(iconPath))
        }
    }

    /// Zips `staged`'s contents into `output` with `ditto`, which
    /// keeps the launcher's executable bit; the metadata flags keep
    /// macOS's `._` side files out of an archive Claude Desktop
    /// unpacks as plain files.
    static func pack(_ staged: URL, to output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--norsrc", "--noextattr", "--noacl",
            staged.path, output.path,
        ]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure.packFailed(process.terminationStatus)
        }
    }

    /// Builds a fresh bundle for the running copy and opens it in
    /// Claude Desktop. The build runs off the main actor; each click
    /// replaces the previous one in the one temporary folder.
    @MainActor
    static func addToClaudeDesktop() async throws {
        guard RunningCopy.location != .translocated else {
            throw Failure.translocated
        }
        guard let claude = claudeDesktop() else {
            throw Failure.noClaudeDesktop
        }
        let executable = RunningCopy.executablePath
        let version = KiwiDeskVersion.semantic
        let icon = appIcon()
        let output = try await Task.detached(priority: .userInitiated) {
            try build(executable: executable, version: version, icon: icon)
        }.value
        try await open(output, with: claude)
    }

    /// Stages and packs the bundle in the one temporary folder,
    /// keeping only the `.mcpb`.
    private static func build(
        executable: String,
        version: String,
        icon: Data?
    ) throws -> URL {
        let files = FileManager.default
        let folder = files.temporaryDirectory
            .appendingPathComponent("KiwiDesk-mcpb")
        try? files.removeItem(at: folder)
        let staged = folder.appendingPathComponent("bundle")
        let output = folder.appendingPathComponent(fileName)
        try stage(
            in: staged,
            executable: executable,
            version: version,
            icon: icon
        )
        try pack(staged, to: output)
        try? files.removeItem(at: staged)
        return output
    }

    @MainActor
    private static func open(_ bundle: URL, with claude: URL) async throws {
        try await withCheckedThrowingContinuation {
            (done: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [bundle],
                withApplicationAt: claude,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if error == nil {
                    done.resume()
                } else {
                    done.resume(throwing: Failure.openFailed)
                }
            }
        }
    }

    /// The app's icon as a 512-point PNG, the size the bundle
    /// format recommends.
    @MainActor
    private static func appIcon() -> Data? {
        let side = 512
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: side,
                pixelsHigh: side,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSApp.applicationIconImage.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side)
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
