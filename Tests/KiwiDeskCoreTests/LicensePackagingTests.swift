import Foundation
import Testing

/// The license texts the bundle carries and the copyright line it
/// declares (#1407, packaging-and-release.md ▸ Building the .app)
/// — `SparklePackagingTests`' sibling. Every failure here is
/// invisible on the build machine, so the script's ORDER and
/// REFUSAL are pinned, the copyright derivation is RUN against
/// the real `LICENSE`, and `ACKNOWLEDGEMENTS` is held verbatim
/// against every third-party component the tree declares.
@Suite("License packaging (#1407)")
struct LicensePackagingTests {
    private let root = scriptFixtureRepoRoot()

    /// Both texts land in `Contents/Resources` before the seal,
    /// or the signature covers a bundle without them.
    @Test("both texts are copied before signing")
    func textsCopiedBeforeSigning() throws {
        let text = try buildAppScriptWithoutComments()
        let loop = try buildAppScriptIndex(
            "for doc in ",
            in: text,
            "the license-text loop is gone"
        )
        let loopLine = text[
            text.index(text.startIndex, offsetBy: loop)...
        ]
        .prefix { $0 != "\n" }
        for doc in ["LICENSE", "ACKNOWLEDGEMENTS"] {
            #expect(
                loopLine.contains(" \(doc)"),
                Comment(rawValue: "\(doc) is not in the copy list")
            )
        }
        let copy = try buildAppScriptIndex(
            #"cp "$ROOT/$doc" "$RES/$doc.txt""#,
            in: text,
            "the license texts are never copied"
        )
        let signing = try buildAppScriptIndex(
            #"echo "==> codesign"#,
            in: text,
            "the signing step is gone"
        )
        #expect(loop < copy)
        #expect(
            copy < signing,
            "a text added after the seal breaks the signature"
        )
    }

    /// A missing source text is refused, never skipped.
    @Test("a missing text is refused, not skipped")
    func missingTextIsFatal() throws {
        let text = try buildAppScriptWithoutComments()
        let check = try buildAppScriptIndex(
            #"if [ ! -f "$ROOT/$doc" ]; then"#,
            in: text,
            "the missing-text check is gone"
        )
        let after = String(
            text[text.index(text.startIndex, offsetBy: check)...]
        )
        let refusal = try buildAppScriptIndex(
            "exit 1",
            in: after,
            "the missing-text check no longer refuses"
        )
        let copy = try buildAppScriptIndex(
            #"cp "$ROOT/$doc" "$RES/$doc.txt""#,
            in: text,
            "the copy is gone"
        )
        #expect(check + refusal < copy)
    }

    /// The plist's copyright is the derivation's output, and the
    /// derivation — run here under the script's own `set` line —
    /// reads the licensor, the year and the title off `LICENSE`.
    @Test("the copyright line is derived from LICENSE")
    func copyrightIsDerived() throws {
        let text = try buildAppScriptWithoutComments()
        #expect(
            text.range(
                of: #"<key>NSHumanReadableCopyright</key>\s*"#
                    + #"<string>\$COPYRIGHT</string>"#,
                options: .regularExpression
            ) != nil,
            "the plist no longer takes the derived line"
        )
        let start = try buildAppScriptIndex(
            #"LICENSE_FILE="$ROOT/LICENSE""#,
            in: text,
            "the derivation no longer reads LICENSE"
        )
        let end = try buildAppScriptIndex(
            #"COPYRIGHT=""#,
            in: text,
            "the derivation no longer assigns COPYRIGHT"
        )
        try #require(start < end)
        let from = text.index(text.startIndex, offsetBy: start)
        let tail = text[text.index(text.startIndex, offsetBy: end)...]
        let assignment = String(tail.prefix { $0 != "\n" })
        // The SHAPE: composed from the three reads, never typed.
        // A literal agreeing with LICENSE today would pass the
        // run below until the day LICENSE moved.
        for atom in ["$LICENSE_YEAR", "$LICENSOR", "$LICENSE_NAME"] {
            #expect(
                assignment.contains(atom),
                Comment(rawValue: "COPYRIGHT= no longer reads \(atom)")
            )
        }
        let snippet = String(text[from..<tail.startIndex]) + assignment
        let run = try spawn(
            "/bin/bash",
            [
                "-c",
                "set -euo pipefail\nROOT=\"$1\"\n\(snippet)\n"
                    + "printf '%s' \"$COPYRIGHT\"",
                "bash",
                root.path,
            ]
        )
        #expect(run.status == 0, Comment(rawValue: run.stderr))

        let license = try String(
            contentsOf: root.appendingPathComponent("LICENSE"),
            encoding: .utf8
        )
        let lines = license.split(separator: "\n")
        let title = try #require(lines.first.map(String.init))
        let licensor = try #require(
            lines.first { $0.hasPrefix("Licensor:") }
                .map {
                    $0.dropFirst("Licensor:".count)
                        .trimmingCharacters(in: .whitespaces)
                }
        )
        #expect(!licensor.isEmpty)
        #expect(run.stdout.contains(licensor))
        #expect(run.stdout.contains(title))
        #expect(
            run.stdout.range(
                of: #"^© [0-9]{4} "#,
                options: .regularExpression
            ) != nil,
            Comment(rawValue: run.stdout)
        )
    }

    /// `ACKNOWLEDGEMENTS` carries the LICENSE of every third-party
    /// component the tree declares, VERBATIM. The roster is
    /// derived — `Vendor/*` plus `Package.resolved`'s pins, each
    /// resolved to the LICENSE SwiftPM fetched — never listed
    /// here, so a component joining the bundle without its notice
    /// reds rather than slipping past a hand-kept pair.
    @Test("the acknowledgements carry every notice verbatim")
    func acknowledgementsCarryTheNotices() throws {
        let notices = try String(
            contentsOf: root.appendingPathComponent(
                "ACKNOWLEDGEMENTS"
            ),
            encoding: .utf8
        )
        let roster = try Self.thirdPartyLicenses(under: root)
        // Non-vacuity: the two components this suite was written
        // for are the floor, not the list.
        #expect(roster.count >= 2, Comment(rawValue: "\(roster)"))
        for (component, url) in roster {
            let license = try String(contentsOf: url, encoding: .utf8)
            #expect(
                notices.contains(
                    license.trimmingCharacters(in: .newlines)
                ),
                Comment(
                    rawValue:
                        "\(component)'s notice (\(url.path)) is not "
                        + "in ACKNOWLEDGEMENTS verbatim"
                )
            )
        }
    }

    /// Component name → its LICENSE file, for every `Vendor/*`
    /// directory and every `Package.resolved` pin. A pin whose
    /// LICENSE cannot be found is a failed requirement, not a
    /// skip: the package must be built for this to run at all.
    static func thirdPartyLicenses(
        under root: URL
    ) throws -> [(String, URL)] {
        let fm = FileManager.default
        var found: [(String, URL)] = []
        let vendor = root.appendingPathComponent("Vendor")
        for dir in try fm.contentsOfDirectory(
            at: vendor,
            includingPropertiesForKeys: nil
        )
        .sorted(by: { $0.path < $1.path }) {
            let license = dir.appendingPathComponent("LICENSE")
            #expect(
                fm.fileExists(atPath: license.path),
                Comment(rawValue: "\(dir.lastPathComponent)/LICENSE")
            )
            found.append((dir.lastPathComponent, license))
        }
        struct Resolved: Decodable {
            struct Pin: Decodable { let identity: String }
            let pins: [Pin]
        }
        let resolved = try JSONDecoder().decode(
            Resolved.self,
            from: Data(
                contentsOf: root.appendingPathComponent(
                    "Package.resolved"
                )
            )
        )
        for pin in resolved.pins {
            let license = try #require(
                fetchedLicense(for: pin.identity, under: root),
                Comment(
                    rawValue:
                        "no LICENSE for \(pin.identity) under "
                        + ".build/artifacts or .build/checkouts — "
                        + "build the package first"
                )
            )
            found.append((pin.identity, license))
        }
        return found
    }

    /// The `LICENSE` SwiftPM fetched for a pin: the binary
    /// artifact's first, since that is what ships, else the
    /// source checkout's.
    private static func fetchedLicense(
        for identity: String,
        under root: URL
    ) -> URL? {
        let build = root.appendingPathComponent(".build")
        for parent in ["artifacts", "checkouts"] {
            let base = build.appendingPathComponent(parent)
            guard
                let walk = FileManager.default.enumerator(
                    at: base,
                    includingPropertiesForKeys: nil
                )
            else { continue }
            for case let url as URL in walk
            where url.lastPathComponent == "LICENSE" {
                let relative = url.path.dropFirst(base.path.count)
                if relative.lowercased().contains(identity.lowercased()) {
                    return url
                }
            }
        }
        return nil
    }
}
