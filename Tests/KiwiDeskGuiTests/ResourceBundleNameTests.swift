import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `ResourceBundle.locate` is asked for a bundle **by name**, and
/// those names — SwiftPM's generated `<package>_<target>` — are
/// typed by hand at two sites (#89). Nothing else checks them,
/// and both failure paths are silent:
///
/// - under `swift test` the host is not an `.app`, so a wrong
///   name misses the `resourceURL` branch and falls through to
///   `Bundle.module`, which resolves — every locale, palette and
///   font suite stays green;
/// - inside the `.app` a wrong name returns `Bundle.main` rather
///   than trapping, deliberately, so the callers' graceful paths
///   run — and the app ships with no locales, no palettes, no app
///   font and no wordmark.
///
/// So a package or target rename lands green on every gate and
/// breaks only for users: the same invisible-on-the-build-machine
/// class `ResourceBundle` exists to close, which is why the
/// literals need a pin of their own (AGENTS.md §5).
///
/// **The pin has to be against the filesystem.** The obvious
/// assertion — that `Bundle.kiwiDeskCore` has the expected
/// basename — cannot fail: when the literal is wrong the
/// fallback hands back SwiftPM's bundle anyway, so it passes
/// either way (verified by deliberately renaming the literal).
/// A guard that cannot fire is worse than none, so this compares
/// the literals against the bundles actually emitted into
/// `.build`, which is what `scripts/build-app.sh` copies.
@Suite("Resource-bundle names")
struct ResourceBundleNameTests {

    @Test("The literals match the bundles SwiftPM emits")
    func literalsMatchEmittedBundles() throws {
        let build = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(".build")
        let fm = FileManager.default
        guard
            let walker = fm.enumerator(
                at: build,
                includingPropertiesForKeys: nil
            )
        else {
            Issue.record("no .build directory to scan")
            return
        }

        var emitted: Set<String> = []
        for case let url as URL in walker
        where url.pathExtension == "bundle"
            && url.lastPathComponent.hasPrefix("KiwiDesk_")
        {
            emitted.insert(url.lastPathComponent)
        }

        // Only meaningful once a build has produced them; the
        // gate always runs `swift build` first.
        try #require(
            !emitted.isEmpty,
            "no KiwiDesk_*.bundle under .build — build first"
        )

        for name in [
            Bundle.kiwiDeskCoreName, Bundle.kiwiDeskGuiName,
        ] {
            #expect(
                emitted.contains("\(name).bundle"),
                """
                No bundle named \(name).bundle was emitted — a \
                package or target rename. Inside the .app this \
                fails silently: resources just go missing. \
                Emitted: \(emitted.sorted().joined(separator: ", "))
                """
            )
        }
    }

    /// A bundle that resolves but is empty (a partial copy, a bad
    /// `build-app.sh` change) should not read as healthy.
    @Test("The Core bundle carries its resources")
    func coreBundleCarriesItsResources() {
        let bundle = Bundle.kiwiDeskCore
        for resource in ["Locales", "Palettes", "AppFont"] {
            #expect(
                bundle.url(
                    forResource: resource,
                    withExtension: nil
                ) != nil,
                "Core resource bundle is missing \(resource)"
            )
        }
    }
}
