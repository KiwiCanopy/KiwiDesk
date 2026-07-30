import Foundation
import Testing

/// Every SwiftUI hosting root must be wrapped in
/// `LocaleScopedRoot`, or the language switch stops working for
/// whatever it hosts.
///
/// `L(_:_:)` is a plain function, so a view that calls it has no
/// dependency on the current locale and SwiftUI never re-renders
/// it when the language changes. Only the handful of views that
/// declared `@EnvironmentObject LocalizationManager` repainted;
/// everything else kept the old language until the app was
/// restarted. That shipped from #9 all the way to eleven locales
/// without anyone noticing, because the bug is invisible unless
/// you switch language *mid-session* — nobody does that while
/// writing a feature, and every test builds a view fresh.
///
/// So the invariant gets a source scan rather than trust: adding
/// another window and forgetting the wrapper is exactly the shape
/// of mistake that produced the bug, and nothing else would catch
/// it.
@Suite("hosting roots are locale-scoped")
struct HostingRootLocaleScopeTests {
    /// `NSHostingView(rootView:` / `NSHostingController(rootView:`
    /// call sites, with the ~6 lines that follow each — enough to
    /// carry the root expression across swift-format's wrapping.
    private func hostingRoots() throws -> [(String, String)] {
        var found: [(String, String)] = []
        for file in try sourceFiles(under: "Sources/KiwiDesk") {
            let text = try String(contentsOf: file, encoding: .utf8)
            let lines = text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(
                    in: .whitespaces
                )
                guard !trimmed.hasPrefix("//"),
                    line.contains("NSHostingView(")
                        || line.contains("NSHostingController(")
                else { continue }
                let end = min(index + 7, lines.count)
                found.append(
                    (
                        file.lastPathComponent,
                        lines[index..<end].joined(separator: "\n")
                    )
                )
            }
        }
        return found
    }

    private func sourceFiles(under path: String) throws -> [URL] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(path)
        guard
            let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )
        else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    @Test("every hosting root wraps its view in LocaleScopedRoot")
    func everyHostingRootIsLocaleScoped() throws {
        let roots = try hostingRoots()
        // A scan that found nothing would "pass" forever.
        #expect(!roots.isEmpty)
        for (file, snippet) in roots {
            #expect(
                snippet.contains("LocaleScopedRoot"),
                """
                \(file) hosts a SwiftUI root without \
                LocaleScopedRoot. Its strings will not follow a \
                language change until the app restarts — wrap the \
                root view, do not add @EnvironmentObject to the \
                views inside it.
                """
            )
        }
    }

    /// The wrapper is useless without the object it observes, and
    /// a missing `.environmentObject` is a crash at runtime rather
    /// than a quiet fallback — worth pinning beside the wrapper.
    @Test("every hosting root injects LocalizationManager")
    func everyHostingRootInjectsTheManager() throws {
        for (file, snippet) in try hostingRoots() {
            #expect(
                snippet.contains("LocalizationManager.shared"),
                Comment(
                    rawValue: "\(file) hosts a SwiftUI root "
                        + "without injecting "
                        + "LocalizationManager.shared"
                )
            )
        }
    }
}
