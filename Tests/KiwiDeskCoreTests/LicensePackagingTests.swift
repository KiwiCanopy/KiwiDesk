import Foundation
import Testing

/// The license texts the bundle carries, and the copyright line it
/// declares (#1407) — `SparklePackagingTests`' sibling.
///
/// BSL 1.1 wants the License displayed on every copy, and the Lua
/// and Sparkle notices want theirs in every copy; the `.app` is a
/// copy. Every failure here is invisible on the build machine —
/// the bundle assembles, signs and notarizes without the texts —
/// so the ORDER and the REFUSAL are pinned in the script the way
/// the Sparkle suite pins them, and the copyright derivation is
/// RUN against the real `LICENSE` rather than read.
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

    /// A missing source text is refused, never skipped — the
    /// bundle would ship without the one file its license
    /// requires, and nothing downstream would notice.
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
    /// derivation — run here as the script runs it — reads the
    /// licensor, the year and the license's title off `LICENSE`.
    /// A hand-typed string would agree with the license until the
    /// day it did not, and the plist is the one place a Finder
    /// Get Info reader sees.
    @Test("the copyright line is derived from LICENSE")
    func copyrightIsDerived() throws {
        let text = try buildAppScriptWithoutComments()
        #expect(
            text.contains(
                "<key>NSHumanReadableCopyright</key>\n"
                    + "    <string>$COPYRIGHT</string>"
            ),
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
        #expect(start < end)
        let from = text.index(text.startIndex, offsetBy: start)
        let tail = text[text.index(text.startIndex, offsetBy: end)...]
        let snippet =
            String(text[from..<tail.startIndex])
            + String(tail.prefix { $0 != "\n" })
        let run = try spawn(
            "/bin/bash",
            [
                "-c",
                "set -e\nROOT=\"$1\"\n\(snippet)\n"
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
        #expect(run.stdout.hasPrefix("© "))
        #expect(run.stdout.contains(licensor))
        #expect(run.stdout.contains(title))
        #expect(
            run.stdout.range(
                of: #"© [0-9]{4} "#,
                options: .regularExpression
            ) != nil,
            Comment(rawValue: run.stdout)
        )
    }

    /// `ACKNOWLEDGEMENTS` carries each third-party notice
    /// VERBATIM — the vendored Lua one, and the LICENSE of the
    /// Sparkle release SwiftPM resolved into `.build/artifacts`.
    /// A bump that changes either text reds here, which is the
    /// point: the notice shipped must be the one the shipped
    /// component carries.
    @Test("the acknowledgements carry both notices verbatim")
    func acknowledgementsCarryTheNotices() throws {
        let notices = try String(
            contentsOf: root.appendingPathComponent(
                "ACKNOWLEDGEMENTS"
            ),
            encoding: .utf8
        )
        let lua = try String(
            contentsOf:
                root
                .appendingPathComponent("Vendor")
                .appendingPathComponent("CLua")
                .appendingPathComponent("LICENSE"),
            encoding: .utf8
        )
        #expect(
            notices.contains(lua.trimmingCharacters(in: .newlines)),
            "the Lua notice is not the vendored LICENSE verbatim"
        )
        let sparkle = try String(
            contentsOf: try #require(
                Self.sparkleLicense(under: root),
                """
                no Sparkle LICENSE under .build/artifacts — build \
                the package first; the notice cannot be checked \
                against a release nobody has resolved
                """
            ),
            encoding: .utf8
        )
        #expect(
            notices.contains(
                sparkle.trimmingCharacters(in: .newlines)
            ),
            "the Sparkle notice is not the resolved LICENSE verbatim"
        )
    }

    /// The `LICENSE` inside SwiftPM's extracted Sparkle artifact,
    /// wherever this toolchain's `.build/artifacts` layout put it.
    private static func sparkleLicense(under root: URL) -> URL? {
        let artifacts =
            root
            .appendingPathComponent(".build")
            .appendingPathComponent("artifacts")
        guard
            let walk = FileManager.default.enumerator(
                at: artifacts,
                includingPropertiesForKeys: nil
            )
        else { return nil }
        for case let url as URL in walk
        where url.lastPathComponent == "LICENSE"
            && url.path.lowercased().contains("sparkle")
        {
            return url
        }
        return nil
    }
}
