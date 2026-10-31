import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// App icons read from disk draw without the alias arrow (#2819):
/// macOS 27 links `/Applications/Safari.app` into its cryptex, and
/// `icon(forFile:)` badges a link path. `AppIconCache.fileIcon`
/// resolves the link; every disk icon read goes through it.
/// Main-actor spend: three icon reads; the scan runs off it.
@Suite("App icons resolve symlinks (#2819)")
struct AppIconAliasTests {
    private static let target = "/System/Applications/Calculator.app"

    @MainActor
    @Test("A symlinked app draws the target's icon")
    func symlinkDrawsTargetIcon() throws {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("AppIconAlias-\(UUID())")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        let link = dir.appendingPathComponent("Calculator.app").path
        try FileManager.default.createSymbolicLink(
            atPath: link,
            withDestinationPath: Self.target
        )
        let plain = Self.pixels(
            NSWorkspace.shared.icon(forFile: Self.target)
        )
        // Negative control: the raw link read carries the badge,
        // so the fixture reaches the defect.
        let badged = Self.pixels(
            NSWorkspace.shared.icon(forFile: link)
        )
        #expect(badged != plain)
        let resolved = Self.pixels(AppIconCache.fileIcon(atPath: link))
        #expect(resolved == plain)
    }

    @Test("Every icon(forFile:) call is AppIconCache.fileIcon's")
    func everyFileIconReadResolves() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        var sites: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let text = Array(try SourceScan.strippedSource(at: file))
            let calls = SourceScan.callSites(in: text, for: ".icon")
            for site in calls {
                guard var at = site.paren.map({ $0 + 1 }) else {
                    continue
                }
                while at < text.count, text[at].isWhitespace {
                    at += 1
                }
                if String(text[at...].prefix(8)) == "forFile:" {
                    sites.append(file.lastPathComponent)
                }
            }
        }
        #expect(sites == ["AppIconCache.swift"])
    }

    /// RGBA bytes of `image` drawn at a fixed 64 px square.
    private static func pixels(_ image: NSImage) -> Data {
        let side = 64
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: side * 4,
            bitsPerPixel: 32
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(
            bitmapImageRep: rep
        )
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return Data(bytes: rep.bitmapData!, count: side * side * 4)
    }
}
