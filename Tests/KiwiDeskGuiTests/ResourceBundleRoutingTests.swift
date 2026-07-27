import Foundation
import Testing

/// Bundled resources must be reached through
/// `ResourceBundle.locate` — `Bundle.kiwiDeskCore` or
/// `Bundle.kiwiDeskGui` — never through SwiftPM's generated
/// `Bundle.module` (#89).
///
/// This guard exists because the failure it prevents **cannot be
/// observed on the machine that writes it.** `Bundle.module`'s
/// accessor searches `Bundle.main.bundleURL`, which inside an
/// `.app` is the bundle root — where codesign refuses to seal
/// anything — and then falls back to an absolute path into the
/// `.build` directory that compiled it. So on the developer's
/// Mac every layout resolves and looks correct; on any other
/// machine the accessor matches neither candidate and calls
/// `fatalError` at first access. Local QA, CI and the whole test
/// suite all pass either way.
///
/// The nine call sites converted with the fix are not what this
/// protects. The tenth one is — added later, compiling cleanly,
/// green everywhere, and crashing every user's app on launch.
///
/// **The lens, not the list**, as in `VisibleBoundsRoutingTests`:
/// the scan pins a per-file *count* across both source trees, so
/// an unlisted new use fails on arrival and a *removed* listed
/// one fails too. A count only the status quo can satisfy is the
/// shape of a guard that has quietly stopped guarding.
@Suite("Resource-bundle routing")
struct ResourceBundleRoutingTests {
    /// Every Swift target, discovered rather than listed: a
    /// third one (a login-item helper, an XPC service — both
    /// plausible now that a signed `.app` exists) would
    /// otherwise be scanned by nothing, and the guard's whole
    /// argument is about the code not yet written.
    private var sourceRoots: [URL] {
        let sources = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let entries = try? FileManager.default
            .contentsOfDirectory(
                at: sources,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        return (entries ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory == true
        }
    }

    /// Every file allowed to name `Bundle.module`, by path under
    /// `Sources/`, with today's exact count and why it is outside
    /// the resolver. Anything absent must be at zero.
    ///
    /// **This map is the exemption list** — AGENTS.md §5 carries
    /// the principle and points here rather than restating which
    /// files qualify.
    ///
    /// Both entries are the *argument* to `locate`, which is the
    /// only legitimate use: `Bundle.module` is per-target and
    /// cannot be reached from Core, so each target passes its own
    /// as the non-`.app` fallback.
    private let allowed: [String: Int] = [
        "KiwiDeskCore/App/ResourceBundle.swift": 1,
        "KiwiDesk/GuiResourceBundle.swift": 1,
    ]

    @Test("Only the allowlisted files name Bundle.module")
    func moduleBundleStaysInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        for root in sourceRoots {
            let prefix =
                root.deletingLastPathComponent().path + "/"
            for file in try SourceScan.swiftSources(under: root) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                // The needle is the **bare** `.module`, not the
                // qualified `Bundle.module`. Matching only the
                // qualified form failed CLOSED on arrival: the
                // two legitimate uses are written
                // `fallback: .module`, so the scan found zero
                // hits anywhere and the guard could never fire
                // for anything. A member reference is always
                // written with the leading dot, so this catches
                // both spellings.
                let hits = source.occurrences(of: ".module")
                guard hits > 0 else { continue }
                let key = String(
                    file.path.dropFirst(prefix.count)
                )
                counts[key, default: 0] += hits
            }
        }

        for (path, found) in counts.sorted(by: { $0.key < $1.key }) {
            #expect(
                allowed[path] == found,
                """
                \(path) names Bundle.module \(found)x, allowed \
                \(allowed[path].map(String.init) ?? "0"). Route \
                it through Bundle.kiwiDeskCore / \
                Bundle.kiwiDeskGui — Bundle.module resolves only \
                on the machine that built it.
                """
            )
        }
        for (path, expected) in allowed where counts[path] == nil {
            #expect(
                expected == 0,
                """
                \(path) no longer names Bundle.module — drop its \
                allowlist entry so the guard keeps biting.
                """
            )
        }
    }
}
