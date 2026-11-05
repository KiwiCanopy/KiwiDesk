import Foundation
import Testing

/// Holds `site.yml`'s list to what the gate actually touches, derived
/// from the gate rather than typed, so deleting an entry reds and a new
/// outside read is caught. Sees the shapes the tree uses: a read built
/// any other way (a helper, a computed path) goes unseen, and a read
/// under `site/` is covered by that entry anyway.
extension SiteGateRequiredTests {
    private static func captures(
        _ pattern: String,
        in text: String
    ) throws -> [[String]] {
        let regex = try NSRegularExpression(
            pattern: pattern,
            options: .anchorsMatchLines
        )
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: whole).map { match in
            (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text)
                    .map { String(text[$0]) } ?? ""
            }
        }
    }

    private static func gitOutput(_ arguments: [String]) throws -> String {
        let run = try spawn(
            "/usr/bin/git",
            arguments,
            currentDirectory: scriptFixtureRepoRoot()
        )
        try #require(run.status == 0, "git \(arguments): \(run.stderr)")
        return run.stdout
    }

    private static func read(_ path: String) throws -> String {
        try String(
            contentsOf: scriptFixtureRepoRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// The build job's working directory and the scripts it runs.
    private static func gateJob() throws -> (root: String, scripts: [String]) {
        let yaml = try workflowSource("site.yml")
        let build = try #require(CiPathFilterTests.jobBlock("build", in: yaml))
        let root = try #require(
            captures(#"working-directory: (\S+)$"#, in: build).first?.first,
            "the build job names no working directory"
        )
        let scripts = try captures(#"\.\./(scripts/[\w.-]+)"#, in: build)
            .map { $0[0] }
        try #require(!scripts.isEmpty, "the build job runs no ../scripts")
        return (root, scripts)
    }

    /// Those scripts and every repo module they import, transitively.
    private static func gateScripts(from roots: [String]) throws -> [String] {
        var seen: [String] = []
        var work = roots
        while let script = work.popLast() {
            if seen.contains(script) { continue }
            seen.append(script)
            let modules = try captures(
                #"^(?:from|import) (\w+)"#,
                in: read(script)
            )
            for module in modules {
                let path = "scripts/\(module[0]).py"
                let url = scriptFixtureRepoRoot()
                    .appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: url.path) {
                    work.append(path)
                }
            }
        }
        return seen
    }

    /// Repo paths those scripts join onto `REPO`.
    private static func repoJoins(in scripts: [String]) throws -> [String] {
        try scripts.flatMap { script in
            try captures(#"REPO((?: / "[^"]+")+)"#, in: read(script)).map {
                $0[0].components(separatedBy: " / ")
                    .dropFirst()
                    .map { $0.filter { $0 != "\"" } }
                    .joined(separator: "/")
            }
        }
    }

    /// Where the tracked symlinks under `root` lead, from the repo root.
    private static func symlinkTargets(under root: String) throws -> [String] {
        let repo = scriptFixtureRepoRoot().standardized
        let links = try gitOutput(["ls-files", "-s", root])
            .split(separator: "\n")
            .filter { $0.hasPrefix("120000 ") }
            .compactMap { $0.split(separator: "\t").last.map(String.init) }
        return try links.map { link in
            let url = repo.appendingPathComponent(link)
            let target = try FileManager.default
                .destinationOfSymbolicLink(atPath: url.path)
            return url.deletingLastPathComponent()
                .appendingPathComponent(target)
                .standardized.path
                .replacingOccurrences(of: repo.path + "/", with: "")
        }
    }

    /// Repo-root files the site's own sources climb out to read.
    private static func parentReads(under root: String) throws -> [String] {
        let sources = try gitOutput(["ls-files", root])
            .split(separator: "\n")
            .map(String.init)
            .filter {
                $0.hasSuffix(".ts") || $0.hasSuffix(".mjs")
                    || $0.hasSuffix(".astro")
            }
        return try sources.flatMap { source in
            let text = try read(source)
            let spelled =
                try captures(#""\.\./([\w.-]+)""#, in: text)
                + captures(#""\.\.", "([\w.-]+)""#, in: text)
            return spelled.map { $0[0] }.filter {
                let url = scriptFixtureRepoRoot()
                    .appendingPathComponent($0)
                return FileManager.default.fileExists(atPath: url.path)
            }
        }
    }

    @Test("Everything the gate runs, imports or reads is on the list")
    func gateInputsAreListed() throws {
        let job = try Self.gateJob()
        let scripts = try Self.gateScripts(from: job.scripts)
        #expect(
            scripts.count > job.scripts.count,
            "no repo module import found: the walk read nothing"
        )
        let joins = try Self.repoJoins(in: scripts)
        let links = try Self.symlinkTargets(under: job.root)
        let parents = try Self.parentReads(under: job.root)
        #expect(!joins.isEmpty, "no REPO join found")
        #expect(!links.isEmpty, "no symlink under the site found")
        #expect(!parents.isEmpty, "no read above the site found")

        let required = Set(
            [job.root, Self.workflowPath] + scripts + joins + links + parents
        )
        let root = scriptFixtureRepoRoot()
        for input in required.sorted() {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: root.appendingPathComponent(input).path,
                isDirectory: &isDirectory
            )
            #expect(exists, "\(input) is gone from the tree")
            let probe = isDirectory.boolValue ? "\(input)/probe.txt" : input
            #expect(
                try Self.verdict(changing: [probe]) == "run=true",
                "the gate reads \(input), so a PR on it must build"
            )
        }
    }
}
