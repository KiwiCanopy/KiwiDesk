import Foundation
import Testing

/// Every workflow selects the one Xcode `release.yml`'s `XCODE`
/// names (packaging-and-release.md): a green PR stream vouches for
/// the compiler a release ships with only while the pins agree,
/// and a bump that edits one file stays green everywhere else.
@Suite("Xcode pin parity")
struct XcodePinParityTests {
    private static let fallback = "/Applications/Xcode.app"

    /// The workflows that run on a macOS image, by file name.
    private func macWorkflows() throws -> [String: String] {
        let dir = scriptFixtureRepoRoot()
            .appendingPathComponent(".github/workflows")
        var out: [String: String] = [:]
        for name in try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
        where name.hasSuffix(".yml") {
            let text = try workflowSource(name)
            if text.contains("runs-on: xcode-") { out[name] = text }
        }
        return out
    }

    /// Every `xcode-select -s` target in `text`, in order.
    private func targets(in text: String) -> [String] {
        text.components(separatedBy: "xcode-select -s ").dropFirst()
            .map {
                String($0.prefix { !$0.isWhitespace && $0 != ";" })
            }
    }

    private func count(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func releasePin() throws -> String {
        let text = try workflowSource("release.yml")
        let line = try #require(
            text.components(separatedBy: "\n")
                .first { $0.hasPrefix("  XCODE: ") }
        )
        return String(line.dropFirst("  XCODE: ".count))
            .trimmingCharacters(in: .whitespaces)
    }

    @Test("every macOS job selects the release pin")
    func everyJobSelectsThePin() throws {
        let pin = try releasePin()
        #expect(pin.hasPrefix("/Applications/Xcode_"))
        let workflows = try macWorkflows()
        #expect(workflows["release.yml"] != nil)
        for (name, text) in workflows {
            let found = targets(in: text)
            #expect(!found.isEmpty, "\(name) selects no Xcode")
            // Per job: a whole-file count passes with one job left on
            // the image's default Xcode.
            let jobs = CiPathFilterTests.jobIDs(in: text).compactMap {
                CiPathFilterTests.jobBlock($0, in: text)
            }
            let macJobs = jobs.filter {
                $0.contains("runs-on:") && !$0.contains("runs-on: ubuntu-")
            }
            #expect(!macJobs.isEmpty, "\(name): no macOS job read")
            for job in macJobs {
                #expect(
                    !targets(in: job).isEmpty,
                    "\(name) has a job selecting no Xcode: \(job.prefix(40))"
                )
            }
            for target in found where target != Self.fallback {
                #expect(
                    target == pin || target == #""$XCODE""#,
                    "\(name) selects \(target), release pins \(pin)"
                )
            }
        }
    }

    @Test("a fallback is CI's alone, and it warns")
    func fallbackWarns() throws {
        for (name, text) in try macWorkflows() {
            let fallbacks = targets(in: text)
                .filter { $0 == Self.fallback }.count
            if name == "release.yml" {
                #expect(fallbacks == 0, "release.yml falls back")
                continue
            }
            #expect(
                fallbacks
                    == count(of: "if ! sudo xcode-select -s ", in: text),
                "\(name): a fallback outside the guarded branch"
            )
            #expect(
                fallbacks
                    <= count(of: "::warning::Xcode_", in: text),
                "\(name): a fallback that does not warn"
            )
        }
    }
}
