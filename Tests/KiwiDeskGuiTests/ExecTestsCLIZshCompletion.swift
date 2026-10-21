import Foundation
import Testing

@testable import KiwiDesk

/// The generated zsh shim, run in `/bin/zsh` against a stub
/// `kiwidesk` (#1685 ▸ Ruling 6e), with `compadd` and `_normal`
/// stubbed to print what they were handed. The fish shim is held
/// by `CLICompletionTests`' needles alone: fish is not part of
/// macOS. Spawns shells, so it lives in the ExecTests partition.
@Suite("ExecTests: CLI zsh completion")
struct ExecTestsCLIZshCompletion {
    /// Completes `words` (the last is the word being typed) and
    /// returns the stub's arguments and what the shim printed.
    static func complete(_ words: [String], answer: [String]) throws
        -> (asked: [String], printed: [String])
    {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-zsh-\(UUID().uuidString)")
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
        let shim = directory.appendingPathComponent("_kiwidesk")
        try CLICompletion.Shell.zsh.script
            .write(to: shim, atomically: true, encoding: .utf8)
        let quoted = ([stub.path] + words).map { word in
            "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let program = [
            "compdef() { :; }",
            "compadd() { shift; print -l -- \"$@\"; }",
            "_normal() { print -l -- \"NORMAL $CURRENT\" \"${words[@]}\"; }",
            "source '\(shim.path)'",
            "words=(\(quoted.joined(separator: " ")))",
            "CURRENT=\(words.count + 1)",
            "_kiwidesk",
        ].joined(separator: "\n")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", "-c", program]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let printed = String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init)
        let askedText =
            (try? String(contentsOf: asked, encoding: .utf8)) ?? ""
        let askedLines = askedText.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).dropLast().map(String.init)
        return (askedLines, printed)
    }

    @Test("a quoted or escaped name reaches __complete unquoted")
    func unquotes() throws {
        for typed in [#"Dual\ M"#, #""Dual M"#] {
            let run = try Self.complete(
                ["load_profile", typed],
                answer: ["Dual Monitor"]
            )
            #expect(
                run.asked == [CLICompleter.verb, "load_profile", "Dual M"],
                "\(typed)"
            )
            #expect(run.printed == ["Dual Monitor"])
        }
    }

    @Test("after watch … -- the rest completes as its own command line")
    func watchHandsOver() throws {
        let run = try Self.complete(
            ["watch", "space_change", "--", "echo", "hi"],
            answer: [CLICompleter.defaultDirective]
        )
        #expect(run.printed == ["NORMAL 2", "echo", "hi"])
    }
}
