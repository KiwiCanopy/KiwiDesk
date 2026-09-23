import AppKit
import Testing

@testable import KiwiDeskCore

/// Shipped-resource guards (#294): a bad re-vendor of the
/// SketchyBar App Font assets (scripts/update-app-font.sh)
/// fails here at `swift test` time, never silently at runtime.
@Suite("App font shipped resources")
struct AppFontResourceTests {
    @Test("Bundled font's name table decodes and is non-empty")
    func bundledMapDecodes() throws {
        let map = try #require(AppFontGlyphMap.loadBundled())
        #expect(map.exact.count > 100)
        // Ligatures are :name: tokens; spot-check a stable app.
        #expect(map.ligature(for: "Safari")?.hasPrefix(":") == true)
    }

    @Test("Localized aliases are plain keys in the same map")
    func localizedAliases() throws {
        let map = try #require(AppFontGlyphMap.loadBundled())
        #expect(map.ligature(for: "Activity Monitor") != nil)
        #expect(
            map.ligature(for: "Aktivitätsanzeige")
                == map.ligature(for: "Activity Monitor")
        )
    }

    /// Upstream marks versioned app names with a trailing `*`;
    /// read as an exact key, "Adobe Photoshop 2026" found none.
    @Test("Bundled prefix names match a versioned app name")
    func bundledPrefixNames() throws {
        let map = try #require(AppFontGlyphMap.loadBundled())
        #expect(!map.prefixes.isEmpty)
        #expect(
            map.ligature(for: "Adobe Photoshop 2026") == ":photoshop:"
        )
        #expect(map.exact.keys.allSatisfy { !$0.hasSuffix("*") })
    }

    @Test("Corrupt font data decodes to nil, not a crash")
    func corruptFont() {
        #expect(AppFontGlyphMap.load(fontData: Data()) == nil)
        #expect(
            AppFontGlyphMap.load(fontData: Data(repeating: 0xFF, count: 64))
                == nil
        )
    }

    @Test("Bundled TTF registers and resolves to a font")
    func bundledFontLoads() {
        #expect(AppFont.font(size: 12) != nil)
    }

    /// The drop carried KiwiDesk's own glyph from a fork branch
    /// until upstream shipped it in a release (v2.0.69); this
    /// test is what let that pin be lifted, and what keeps a
    /// later re-vendor from silently dropping the glyph again.
    /// Both halves are asserted because they fail apart: the map
    /// can name a ligature the font has no glyph for, which
    /// renders as a blank App Bar slot rather than falling back
    /// to the app image.
    @Test("Bundled map and TTF both carry the KiwiDesk glyph")
    func kiwiDeskGlyph() throws {
        let map = AppFontGlyphMap.loadBundled()
        #expect(map?.ligature(for: "KiwiDesk") == ":kiwidesk:")
        let font = try #require(AppFont.font(size: 12))
        // A present ligature collapses the whole token into one
        // glyph; a missing one leaves the characters unshaped.
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: ":kiwidesk:",
                attributes: [.font: font]
            )
        )
        #expect(CTLineGetGlyphCount(line) == 1)
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
            return AppFontGlyphMap(["Zed": ":zed:"])
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
            AppFontGlyphMap(["Zed": ":zed:", "Éditeur": ":zed:"])
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
            return AppFontGlyphMap([:])
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
