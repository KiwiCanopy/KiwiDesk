import Foundation
import Testing

@testable import KiwiDesk

/// The generated bash shim, run in the macOS `/bin/bash` (3.2)
/// against a stub `kiwidesk` that records what it was asked
/// (#1685 ▸ Ruling 6e). It spawns shells, so it lives in the
/// ExecTests partition (`MachineTouchTests`).
@Suite("ExecTests: CLI bash completion")
struct ExecTestsCLICompletion {
    struct Run {
        let asked: [String]
        let reply: [String]
    }

    /// Completes `words` (the last is the word being typed) with a
    /// stub that answers `answer`, one candidate per line.
    static func complete(_ words: [String], answer: [String]) throws
        -> Run
    {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-shim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = directory.appendingPathComponent("kiwidesk")
        let asked = directory.appendingPathComponent("asked")
        let reply = answer.map { "printf '%s\\n' '\($0)'" }
        try
            (["#!/bin/sh", "printf '%s\\n' \"$@\" > '\(asked.path)'"]
            + reply).joined(separator: "\n")
            .write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stub.path
        )
        let shim = directory.appendingPathComponent("shim.bash")
        try CLICompletion.Shell.bash.script
            .write(to: shim, atomically: true, encoding: .utf8)
        let quoted = ([stub.path] + words).map { word in
            "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let program = [
            "complete() { :; }",
            "source '\(shim.path)'",
            "COMP_WORDS=(\(quoted.joined(separator: " ")))",
            "COMP_CWORD=\(words.count)",
            "cd '\(directory.path)'",
            "_kiwidesk",
            #"printf '%s\n' "${COMPREPLY[@]}""#,
        ].joined(separator: "\n")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", program]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty }
        let askedText =
            (try? String(contentsOf: asked, encoding: .utf8))
            ?? ""
        return Run(
            asked: askedText.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).dropLast().map(String.init),
            reply: lines
        )
    }

    @Test("an escaped space reaches __complete unescaped")
    func escapedSpace() throws {
        let run = try Self.complete(
            ["load_profile", #"Dual\ M"#],
            answer: ["Dual Monitor"]
        )
        #expect(run.asked == [CLICompleter.verb, "load_profile", "Dual M"])
        #expect(run.reply == [#"Dual\ Monitor"#])
    }

    @Test("inside an open quote the name is offered unescaped")
    func openQuote() throws {
        let run = try Self.complete(
            ["load_profile", #""Dual M"#],
            answer: ["Dual Monitor"]
        )
        #expect(run.asked.last == "Dual M")
        #expect(run.reply == ["Dual Monitor"])
    }

    @Test("an empty word is asked about as empty")
    func emptyWord() throws {
        let run = try Self.complete(["load_profile", ""], answer: [])
        #expect(run.asked == [CLICompleter.verb, "load_profile", ""])
        #expect(run.reply.isEmpty, "fell back to files")
    }

    @Test("after watch … -- a command, then files")
    func watchDefault() throws {
        let directive = [CLICompleter.defaultDirective]
        let command = try Self.complete(
            ["watch", "--", "ech"],
            answer: directive
        )
        #expect(command.reply.contains("echo"))
        let file = try Self.complete(
            ["watch", "--", "echo", "kiwi"],
            answer: directive
        )
        #expect(file.reply == ["kiwidesk"], "\(file.reply)")
    }

    /// `complete -o default` would offer files wherever KiwiDesk
    /// offers nothing; the stubbed runs above cannot see it.
    @Test("the shim registers with no file fallback")
    func registration() throws {
        let shim =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-shim-\(UUID().uuidString)")
        try CLICompletion.Shell.bash.script
            .write(to: shim, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: shim) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c", "source '\(shim.path)'; complete -p kiwidesk",
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let line = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(line == "complete -F _kiwidesk kiwidesk")
    }
}
