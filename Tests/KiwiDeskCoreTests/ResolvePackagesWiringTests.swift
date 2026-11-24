import Foundation
import Testing

/// Every macOS job in `ci.yml` and `release.yml` resolves through
/// `scripts/resolve-packages` before anything that would resolve
/// on its own (#3591): one wiring point per job, so a job without
/// it takes the unretried clone the script exists to replace, and
/// a job spelling the resolve itself is a hand copy of the loop.
@Suite("Every macOS job resolves through the retry (#3591)")
struct ResolvePackagesWiringTests {
    private static let step = "run: scripts/resolve-packages"

    /// Commands that resolve the package when nothing has yet.
    private static let resolvers = [
        "swift build", "swift test", "swift run", "swift package",
        "build-app.sh",
    ]

    /// Each job of a workflow, keyed by its id, comments stripped.
    static func jobs(in yaml: String) throws -> [(String, String)] {
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let top = try #require(
            lines.firstIndex { $0 == "jobs:" },
            "no jobs: block read"
        )
        var jobs: [(String, [Substring])] = []
        for line in lines[(top + 1)...] {
            let indent = line.prefix { $0 == " " }.count
            if !line.isEmpty, indent == 0 { break }
            if indent == 2, line.hasSuffix(":") {
                let id = line.trimmingCharacters(in: .whitespaces)
                jobs.append((String(id.dropLast()), []))
            } else if !jobs.isEmpty {
                jobs[jobs.count - 1].1.append(line)
            }
        }
        return jobs.map { ($0.0, $0.1.joined(separator: "\n")) }
    }

    @Test(
        "Each macOS job resolves once, before any resolving step",
        arguments: ["ci.yml", "release.yml"]
    )
    func everyMacJobResolvesFirst(workflow: String) throws {
        let jobs = try Self.jobs(in: try workflowSource(workflow))
        let mac = jobs.filter { $0.1.contains("runs-on: xcode-") }
        try #require(!mac.isEmpty, "\(workflow): no macOS job read")
        for (id, body) in jobs {
            let isMac = mac.contains { $0.0 == id }
            let wired = body.components(separatedBy: Self.step)
            #expect(
                wired.count - 1 == (isMac ? 1 : 0),
                "\(workflow) \(id) resolves \(wired.count - 1) times"
            )
            #expect(
                !body.contains("swift package resolve"),
                "\(workflow) \(id) hand-copies the resolve"
            )
            let head = wired[0]
            for needle in Self.resolvers {
                #expect(
                    !head.contains(needle),
                    "\(workflow) \(id) runs \(needle) before the retry"
                )
            }
        }
    }

    /// `Select Xcode` picks the toolchain the resolve runs on, so
    /// the step follows it rather than the checkout.
    @Test(
        "The resolve runs on the selected Xcode",
        arguments: ["ci.yml", "release.yml"]
    )
    func resolveFollowsSelectXcode(workflow: String) throws {
        let jobs = try Self.jobs(in: try workflowSource(workflow))
        for (id, body) in jobs where body.contains(Self.step) {
            let select = try #require(
                body.range(of: "- name: Select Xcode"),
                "\(workflow) \(id) selects no Xcode"
            )
            let resolve = try #require(body.range(of: Self.step))
            #expect(
                select.lowerBound < resolve.lowerBound,
                "\(workflow) \(id) resolves before selecting Xcode"
            )
        }
    }
}
