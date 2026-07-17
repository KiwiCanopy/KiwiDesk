import AppKit
import Testing

@testable import KiwiDeskCore

/// Shipped-resource guards (#294): a bad re-vendor of the
/// SketchyBar App Font assets (scripts/update-app-font.sh)
/// fails here at `swift test` time, never silently at runtime.
@Suite("App font shipped resources")
struct AppFontResourceTests {
    @Test("Bundled icon map decodes and is non-empty")
    func bundledMapDecodes() {
        let map = AppFontGlyphMap.loadBundled()
        #expect((map?.count ?? 0) > 100)
        // Ligatures are :name: tokens; spot-check a stable app.
        #expect(map?["Safari"]?.hasPrefix(":") == true)
    }

    @Test("Localized aliases are plain keys in the same map")
    func localizedAliases() {
        let map = AppFontGlyphMap.loadBundled()
        #expect(map?["Activity Monitor"] != nil)
        #expect(
            map?["Aktivitätsanzeige"]
                == map?["Activity Monitor"]
        )
    }

    @Test("Corrupt map file decodes to nil, not a crash")
    func corruptFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-bad-icon-map.json")
        try Data("{\"not\": \"an array\"}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(AppFontGlyphMap.load(from: url) == nil)
    }

    @Test("Bundled TTF registers and resolves to a font")
    func bundledFontLoads() {
        #expect(AppFont.font(size: 12) != nil)
    }
}

/// The `tinted_image` recolor helper (#294): output keeps the
/// input's size and never comes back blank.
@Suite("App icon tinting")
struct AppIconTintTests {
    @Test("Tinting preserves size and yields a drawable image")
    func tintPreservesSize() {
        let size = NSSize(width: 32, height: 32)
        let icon = NSImage(size: size)
        icon.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 32, height: 32).fill()
        icon.unlockFocus()
        let tinted = icon.kiwiTinted(with: .white)
        #expect(tinted.size == size)
        #expect(!tinted.representations.isEmpty)
    }

    @Test("An empty image degrades to itself, not a crash")
    func emptyImageFallsBack() {
        let empty = NSImage(
            size: NSSize(width: 16, height: 16)
        )
        let tinted = empty.kiwiTinted(with: .black)
        #expect(tinted.size.width == 16)
    }
}

/// The shared glyph-vs-image seam (#294): fallback chain,
/// one-time background load, and glyph hits once loaded.
@Suite("App font resolver")
@MainActor
struct AppFontResolverTests {
    @Test("Lookups before the map loads fall back to nil")
    func preLoadFallback() async {
        let gate = DispatchSemaphore(value: 0)
        let resolver = AppFontResolver(loader: {
            gate.wait()
            return ["Zed": ":zed:"]
        })
        await withCheckedContinuation { done in
            resolver.onLoad = { done.resume() }
            // Kicks the load; the loader is still gated, so
            // the lookup answers nil (image fallback).
            #expect(resolver.glyph(forAppName: "Zed") == nil)
            gate.signal()
        }
        #expect(resolver.glyph(forAppName: "Zed") == ":zed:")
    }

    @Test("Known name hits, unknown app falls back to nil")
    func glyphHit() async {
        let resolver = AppFontResolver(loader: {
            ["Zed": ":zed:", "Éditeur": ":zed:"]
        })
        await withCheckedContinuation { done in
            resolver.onLoad = { done.resume() }
            resolver.preload()
        }
        #expect(resolver.glyph(forAppName: "Zed") == ":zed:")
        #expect(resolver.glyph(forAppName: "Éditeur") == ":zed:")
        #expect(resolver.glyph(forAppName: "NoSuchApp") == nil)
    }

    @Test("Loader runs once across repeated lookups")
    func loaderRunsOnce() async {
        final class Count: @unchecked Sendable {
            private let lock = NSLock()
            private var n = 0
            func bump() {
                lock.lock()
                n += 1
                lock.unlock()
            }
            var value: Int {
                lock.lock()
                defer { lock.unlock() }
                return n
            }
        }
        let count = Count()
        let resolver = AppFontResolver(loader: {
            count.bump()
            return [:]
        })
        await withCheckedContinuation { done in
            resolver.onLoad = { done.resume() }
            _ = resolver.glyph(forAppName: "A")
            _ = resolver.glyph(forAppName: "B")
        }
        _ = resolver.glyph(forAppName: "C")
        #expect(count.value == 1)
    }

    @Test("Missing map degrades to image-only, never crashes")
    func corruptMapDegrades() async {
        let resolver = AppFontResolver(loader: { nil })
        await withCheckedContinuation { done in
            resolver.onLoad = { done.resume() }
            resolver.preload()
        }
        #expect(resolver.glyph(forAppName: "Safari") == nil)
    }
}
