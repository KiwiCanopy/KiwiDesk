import Foundation
import Testing

/// Every macOS job in every workflow resolves through
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
        "build-app.sh", "-resolvePackageDependencies",
    ]

    /// A `swift package … resolve` line, any flags between: a
    /// resolve spelled outside the script, retried or not.
    private static let handCopy =
        #"swift\s+package\b[^\n]*\bresolve\b"#

    /// The step's whole `run:` line, so `|| true` after it reads
    /// as unwired rather than wired.
    private static func wiredLines(_ job: String) -> Int {
        job.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces) == step
        }.count
    }

    /// Every workflow, comments stripped, by file name: a new
    /// one is read without being listed here.
    static func workflows() throws -> [String: String] {
        let dir = scriptFixtureRepoRoot()
            .appendingPathComponent(".github/workflows")
        var out: [String: String] = [:]
        for name in try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
        where name.hasSuffix(".yml") {
            out[name] = try workflowSource(name)
        }
        return out
    }

    /// Each job of a workflow as (id, block), through the one
    /// splitter the other per-job workflow guards share.
    static func jobs(in yaml: String) -> [(String, String)] {
        CiPathFilterTests.jobIDs(in: yaml).compactMap { id in
            CiPathFilterTests.jobBlock(id, in: yaml).map { (id, $0) }
        }
    }

    private static func isMac(_ job: String) -> Bool {
        job.contains("runs-on:") && !job.contains("runs-on: ubuntu-")
    }

    @Test("Each macOS job resolves once, before any resolving step")
    func everyMacJobResolvesFirst() throws {
        let workflows = try Self.workflows()
        #expect(workflows["ci.yml"] != nil)
        #expect(workflows["release.yml"] != nil)
        var macJobs = 0
        for (workflow, yaml) in workflows {
            try check(workflow, Self.jobs(in: yaml), &macJobs)
        }
        // ci.yml alone has several; none read means the split broke.
        #expect(macJobs >= 2, "read \(macJobs) macOS jobs")
    }

    private func check(
        _ workflow: String,
        _ jobs: [(String, String)],
        _ macJobs: inout Int
    ) throws {
        for (id, body) in jobs {
            let isMac = Self.isMac(body)
            if isMac { macJobs += 1 }
            let count = Self.wiredLines(body)
            #expect(
                count == (isMac ? 1 : 0),
                "\(workflow) \(id) resolves \(count) times"
            )
            #expect(
                body.range(of: Self.handCopy, options: .regularExpression)
                    == nil,
                "\(workflow) \(id) hand-copies the resolve"
            )
            let wired = body.components(separatedBy: Self.step)
            if wired.count > 1 {
                // A step that may fail without failing the job.
                let step = try workflowStep("Resolve packages", in: body)
                #expect(!step.contains("continue-on-error"))
                #expect(!step.contains("if:"))
            }
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
    @Test("The resolve runs on the selected Xcode")
    func resolveFollowsSelectXcode() throws {
        let jobs = try Self.workflows().flatMap { workflow, yaml in
            Self.jobs(in: yaml).map { (workflow, $0.0, $0.1) }
        }
        for (workflow, id, body) in jobs where body.contains(Self.step) {
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
