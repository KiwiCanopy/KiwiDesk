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

    @Test("Degenerate map entries are dropped, not served")
    func degenerateEntriesDropped() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-degenerate-map.json")
        let json = """
            [
              {"iconName": "", "appNames": ["Ghost"]},
              {"iconName": ":ok:", "appNames": ["", "Real"]}
            ]
            """
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let map = AppFontGlyphMap.load(from: url)
        #expect(map?["Ghost"] == nil)
        #expect(map?[""] == nil)
        #expect(map?["Real"] == ":ok:")
    }
}

/// The shared glyph-vs-image seam (#294): fallback chain,
/// one-time background load, and glyph hits once loaded.
@Suite("App font resolver")
@MainActor
struct AppFontResolverTests {
    /// Awaits the resolver's one-shot load, disarming the
    /// callback after the first fire so a double `onLoad`
    /// regression fails the test instead of double-resuming
    /// (crashing) the continuation.
    private func loaded(
        _ resolver: AppFontResolver,
        kick: @MainActor () -> Void
    ) async {
        await withCheckedContinuation { done in
            resolver.onLoad = {
                resolver.onLoad = {}
                done.resume()
            }
            kick()
        }
    }

    @Test("Lookups before the map loads fall back to nil")
    func preLoadFallback() async {
        let gate = DispatchSemaphore(value: 0)
        let resolver = AppFontResolver(loader: {
            gate.wait()
            return ["Zed": ":zed:"]
        })
        await loaded(resolver) {
            // Kicks the load; the loader is still gated, so
            // the lookup answers nil (image fallback).
            #expect(
                resolver.glyph(
                    forAppName: "Zed",
                    source: .appFont
                ) == nil
            )
            gate.signal()
        }
        #expect(
            resolver.glyph(forAppName: "Zed", source: .appFont)
                == ":zed:"
        )
    }

    @Test("Known name hits; unknown app and image source nil")
    func glyphHit() async {
        let resolver = AppFontResolver(loader: {
            ["Zed": ":zed:", "Éditeur": ":zed:"]
        })
        await loaded(resolver) { resolver.preload() }
        #expect(
            resolver.glyph(forAppName: "Zed", source: .appFont)
                == ":zed:"
        )
        #expect(
            resolver.glyph(
                forAppName: "Éditeur",
                source: .appFont
            ) == ":zed:"
        )
        #expect(
            resolver.glyph(
                forAppName: "NoSuchApp",
                source: .appFont
            ) == nil
        )
        // The icon-source gate lives in the resolver: an
        // image source never yields a glyph, even on a hit.
        #expect(
            resolver.glyph(
                forAppName: "Zed",
                source: .appImage
            ) == nil
        )
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
        await loaded(resolver) {
            _ = resolver.glyph(forAppName: "A", source: .appFont)
            _ = resolver.glyph(forAppName: "B", source: .appFont)
        }
        _ = resolver.glyph(forAppName: "C", source: .appFont)
        #expect(count.value == 1)
    }

    @Test("Missing map degrades to image-only, never crashes")
    func corruptMapDegrades() async {
        let resolver = AppFontResolver(loader: { nil })
        await loaded(resolver) { resolver.preload() }
        #expect(
            resolver.glyph(
                forAppName: "Safari",
                source: .appFont
            ) == nil
        )
    }
}
