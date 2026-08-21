import Foundation
import Testing

/// `scripts/sparkle-public-key.js` derives the public half of
/// the Sparkle signing key, and `release.yml` refuses to sign
/// when it does not match the `SUPublicEDKey` every bundle
/// ships (#874).
///
/// **Why the derivation needs a test of its own.** It is the
/// only piece of cryptography this repo performs, and it is
/// checked against nothing else in the pipeline: if it returned
/// a wrong-but-stable value, the comparison in `release.yml`
/// would refuse the CORRECT key and no release could ever be
/// signed — or, with the constants transposed, accept a wrong
/// one and ship an update every installed copy rejects. So it
/// is pinned against RFC 8032's own test vector rather than
/// against a value this repo produced, which would only prove
/// the code agrees with itself.
@Suite("Sparkle key derivation (#874)")
struct SparkleKeyDerivationTests {
    private var script: URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("sparkle-public-key.js")
    }

    /// Runs the deriver with `stdin` set to `key`.
    private func derive(_ key: String) throws -> ScriptRun {
        let input = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "sparkle-key-\(UUID().uuidString)"
            )
        try key.write(to: input, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: input) }
        return try spawn(
            "/bin/sh",
            [
                "-c",
                "node \(script.path) < \(input.path)",
            ]
        )
    }

    /// RFC 8032 §7.1, TEST 1 — the first Ed25519 vector, quoted
    /// as base64 because that is the form both Sparkle's key
    /// file and `SUPublicEDKey` take.
    private static let rfc8032Seed = Data([
        0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60,
        0xba, 0x84, 0x4a, 0xf4, 0x92, 0xec, 0x2c, 0xc4,
        0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19,
        0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60,
    ])
    private static let rfc8032Public = Data([
        0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
        0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
        0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
        0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a,
    ])

    @Test("the standard's own vector derives correctly")
    func matchesRFC8032() throws {
        let run = try derive(
            Self.rfc8032Seed.base64EncodedString()
        )
        #expect(run.status == 0)
        #expect(
            run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                == Self.rfc8032Public.base64EncodedString()
        )
    }

    /// The legacy 64-byte form is seed followed by public half.
    /// The same derivation covers it, and the carried half is
    /// cross-checked rather than trusted.
    @Test("a legacy seed+public key derives from its seed")
    func handlesLegacyKey() throws {
        let legacy = Self.rfc8032Seed + Self.rfc8032Public
        let run = try derive(legacy.base64EncodedString())
        #expect(run.status == 0)
        #expect(
            run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                == Self.rfc8032Public.base64EncodedString()
        )
    }

    /// A legacy key whose two halves disagree is a corrupt
    /// secret, and signing with it would produce a signature
    /// nothing accepts.
    @Test("a legacy key that contradicts its own seed refuses")
    func refusesInconsistentLegacyKey() throws {
        let wrong = Data(repeating: 0x01, count: 32)
        let run = try derive(
            (Self.rfc8032Seed + wrong).base64EncodedString()
        )
        #expect(run.status != 0)
        #expect(run.stderr.contains("does not match"))
    }

    @Test("a key of the wrong length refuses")
    func refusesWrongLength() throws {
        let run = try derive(
            Data(repeating: 0x02, count: 48)
                .base64EncodedString()
        )
        #expect(run.status != 0)
        #expect(run.stderr.contains("48 bytes"))
    }

    @Test("input that is not base64 refuses")
    func refusesGarbage() throws {
        let run = try derive("this is not a key")
        #expect(run.status != 0)
    }

    /// The check `release.yml` performs, performed here: the
    /// shipped public key is a well-formed Ed25519 public key.
    /// It cannot verify the SECRET matches — that needs the
    /// secret — but it catches a truncated or re-wrapped
    /// `SUPublicEDKey`, which would make every release refuse
    /// to sign.
    @Test("the shipped public key is a 32-byte Ed25519 key")
    func shippedKeyIsWellFormed() throws {
        guard let shipped = try buildAppPlistValue("SUPublicEDKey")
        else {
            Issue.record("build-app.sh declares no SUPublicEDKey")
            return
        }
        let raw = Data(base64Encoded: shipped)
        #expect(raw != nil, "SUPublicEDKey is not base64")
        #expect(raw?.count == 32)
    }
}
