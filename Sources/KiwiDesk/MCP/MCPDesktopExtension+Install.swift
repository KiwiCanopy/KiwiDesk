import AppKit
import KiwiDeskCore

/// Building the `.mcpb` on disk and handing it to Claude Desktop,
/// which shows its own install dialog (#2258 ▸ Ruling).
extension MCPDesktopExtension {
    static let claudeDesktopBundleID = "com.anthropic.claudefordesktop"

    /// Why a hand-off could not start.
    enum Failure: Error, Equatable {
        case noClaudeDesktop
        case packFailed(Int32)
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
    /// keeps the launcher's executable bit.
    static func pack(_ staged: URL, to output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", staged.path, output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure.packFailed(process.terminationStatus)
        }
    }

    /// Builds a fresh bundle for the running copy in a temporary
    /// folder and opens it in Claude Desktop; `openFailed` runs on
    /// the main actor if Claude Desktop refuses the file.
    @MainActor
    static func addToClaudeDesktop(
        openFailed: @escaping @MainActor () -> Void
    ) throws {
        guard let claude = claudeDesktop() else {
            throw Failure.noClaudeDesktop
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KiwiDesk-mcpb-\(UUID().uuidString)")
        let staged = folder.appendingPathComponent("bundle")
        let output = folder.appendingPathComponent(fileName)
        try stage(
            in: staged,
            executable: RunningCopy.executablePath,
            version: KiwiDeskVersion.semantic,
            icon: appIcon()
        )
        try pack(staged, to: output)
        NSWorkspace.shared.open(
            [output],
            withApplicationAt: claude,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard error != nil else { return }
            Task { @MainActor in openFailed() }
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
