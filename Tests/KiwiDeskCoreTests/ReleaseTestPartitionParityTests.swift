import Foundation
import Testing

/// `release.yml`'s test jobs are a hand copy of `ci.yml`'s split
/// (#3108, packaging-and-release.md): one job per test product,
/// each run in its `ExecTests` partitions. A copy that drifted
/// would tag a tree a partition never ran on, and the workflow
/// cannot be exercised before a tag is live.
///
/// Partitions only, never flags: the release copy deliberately
/// takes no warning ratchet (#1594), so its arguments differ from
/// CI's by design. The products are read from `Package.swift`, so
/// a new test target is owed a release job as well as a CI one.
@Suite("Release test partitions match CI's")
struct ReleaseTestPartitionParityTests {
    /// One step's partition: its product and its selectors, e.g.
    /// `KiwiDeskGuiTests --skip ExecTests`; nil when the step names
    /// no product.
    static func partition(of step: String) -> String? {
        let tokens = step.split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard let at = tokens.firstIndex(of: "--test-product"),
            at + 1 < tokens.count
        else { return nil }
        var parts = [tokens[at + 1]]
        for (index, token) in tokens.enumerated()
        where token == "--skip" || token == "--filter" {
            let pattern =
                index + 1 < tokens.count
                ? tokens[index + 1] : ""
            parts.append("\(token) \(pattern)")
        }
        return parts.joined(separator: " ")
    }

    /// Every partition a workflow's test steps run, sorted. A
    /// step naming no product is dropped here; `release.yml` is
    /// held to having none by `releaseRunsOnlyPartitions`.
    static func partitions(in yaml: String) throws -> [String] {
        try CiRequiredJobTests.testSteps(in: yaml)
            .map { try workflowStep($0, in: yaml) }
            .compactMap(partition(of:))
            .sorted()
    }

    @Test("release.yml runs ci.yml's partitions, each once")
    func partitionsMatchCi() throws {
        let ci = try Self.partitions(in: try workflowSource("ci.yml"))
        let release = try Self.partitions(
            in: try workflowSource("release.yml")
        )
        // Two products times two partitions today; fewer means the
        // scrape stopped reading, not that the split shrank.
        #expect(ci.count >= 4, "read too few ci.yml partitions: \(ci)")
        #expect(release == ci, "release.yml \(release) vs ci.yml \(ci)")
    }

    @Test("every release test step names a product")
    func releaseRunsOnlyPartitions() throws {
        let yaml = try workflowSource("release.yml")
        for name in try CiRequiredJobTests.testSteps(in: yaml) {
            let step = try workflowStep(name, in: yaml)
            #expect(
                Self.partition(of: step) != nil,
                "release.yml step \(name) runs an unsplit swift test"
            )
        }
    }

    @Test("release.yml's products are Package.swift's test targets")
    func productsAreTheTestTargets() throws {
        let release = try Self.partitions(
            in: try workflowSource("release.yml")
        )
        let products = Set(
            release.compactMap { $0.split(separator: " ").first }
                .map(String.init)
        )
        let targets = Set(try CiRequiredJobTests.testTargets())
        #expect(products == targets)
    }

    /// Nothing ships unless every test job passed on the tree the
    /// gate vetted. Build and lint ride in a test job, as in
    /// ci.yml, since the verify-gate skill's fast loop owes both.
    @Test("the release waits on every test job, on the vetted tree")
    func releaseWaitsOnTheTestedTree() throws {
        let yaml = try workflowSource("release.yml")
        let release = try #require(
            CiPathFilterTests.jobBlock("release", in: yaml)
        )
        let needsLine = try #require(
            release.split(separator: "\n")
                .first { $0.hasPrefix("    needs: [") },
            "the release job has no `needs: [...]` list"
        )
        let needs = Set(
            needsLine.dropFirst("    needs: [".count).dropLast()
                .components(separatedBy: ", ")
        )
        #expect(needs.contains("gate"))
        let testJobs = CiPathFilterTests.jobIDs(in: yaml).filter {
            CiPathFilterTests.jobBlock($0, in: yaml)?
                .contains("swift test") == true
        }
        #expect(testJobs.count >= 2, "read too few test jobs")
        var built = false
        var linted = false
        for job in testJobs {
            let block = CiPathFilterTests.jobBlock(job, in: yaml) ?? ""
            #expect(needs.contains(job), "release does not need \(job)")
            #expect(
                block.contains("\n    needs: gate\n"),
                "\(job) does not wait on the gate"
            )
            #expect(
                block.contains("ref: ${{ needs.gate.outputs.sha }}"),
                "\(job) does not check out the vetted commit"
            )
            built = built || block.contains("run: swift build\n")
            linted = linted || block.contains("run: ./scripts/lint.sh\n")
        }
        #expect(built, "no test job runs `swift build`")
        #expect(linted, "no test job runs `./scripts/lint.sh`")
    }
}
