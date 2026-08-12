import Foundation
import Testing

@testable import KiwiDesk

/// A dim makes a claim, so something has to say what it is
/// (#815). "Grey, don't hide" keeps a control visible precisely
/// because the dimming means *switch that on and I act* — and a
/// dim that says only "dimmed" tells the reader an answer exists
/// and then withholds it, which is worse than a control that was
/// never gated.
///
/// The invariant this holds is deliberately structural rather
/// than semantic, because "the reason is reachable" is not
/// something a scan can read: **a conditional `.opacity` in the
/// Settings tree is `GreyOut`'s, or it is listed here with what
/// it dims for and where its reason lives.** Three separate
/// implementations of "dim this" already shipped — `GreyOut`,
/// `keybindingRowStyle(inherited:)` and a hand-rolled
/// `.opacity` — so a fourth would have arrived silent with
/// nothing red.
///
/// Stated limit: this counts the DIMMERS, not the reasons. A row
/// listed below whose reason later stops being drawn stays green
/// here; that half is the render guards' and the eye's.
@Suite("No silent dim (#815)")
struct SilentDimTests {
    /// Every conditional dim outside `GreyOut`, and why each is
    /// allowed to be its own. The value is the reason the dim
    /// stands for — an entry that cannot state one is the
    /// finding, not a formality.
    private let allowed: [String: String] = [
        "AutoGatedGroup.swift":
            "GreyOut itself — the modifier every gate should use",
        "InactiveDimmed.swift":
            "not a gate: the whole window fades while it is not "
            + "the key window, so nothing is being withheld and "
            + "there is no per-control reason to give",
        "AppBarOverrideControls.swift":
            "override mode's no-value branch, which cannot use "
            + "GreyOut because it must not compound inside a "
            + "gated block; it carries its own accessibilityHint "
            + "on the single control (`space_override.off.help`), "
            + "which is the LEAF case the backed-out block hint "
            + "was not",
        "KeybindingOverrideEnvironment.swift":
            "inheritance, not a gate: the row still works and the "
            + "dim says the value comes from the base. It carries "
            + "its own accessibilityHint on the row "
            + "(`shortcuts.row.inherited.axhint`), the same leaf "
            + "case as the entry above",
        "AppRuleRow.swift":
            "the same inheritance dim, per facet, for the two "
            + "menus inside the rule sentence",
        "SettingsSlider.swift":
            "the shared slider's own disabled fade, which rides "
            + "`isEnabled` — set by whatever gate disabled it, so "
            + "the reason belongs to that gate and not here",
        "FocusBorderPreview.swift":
            "a PICTURE, not a control: the preview fades while "
            + "the feature is off, and the toggle saying so is "
            + "the row above it",
        "DragVisualPreview.swift":
            "the same, for the drag visuals preview",
    ]

    @Test("a conditional dim is GreyOut's or is listed")
    func everyDimIsAccountedFor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        var found: Set<String> = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            guard source.contains("opacity(") else { continue }
            guard dimmingOpacity(in: source) else { continue }
            let name = file.lastPathComponent
            found.insert(name)
            #expect(
                allowed[name] != nil,
                Comment(
                    rawValue:
                        "\(name) dims a control on a condition "
                        + "without GreyOut. A dim says an answer "
                        + "exists, so route it through GreyOut "
                        + "(which carries the reason), or add an "
                        + "entry to `allowed` saying what it "
                        + "dims for and where the reason is "
                        + "readable without a pointer (#815)."
                )
            )
        }
        // The map is the one copy of who may, so an entry whose
        // file stopped dimming is stale and says so — the same
        // rule every `allowed` map in this tree carries.
        for name in allowed.keys {
            #expect(
                found.contains(name),
                Comment(
                    rawValue:
                        "\(name) no longer dims conditionally — "
                        + "drop its `allowed` entry"
                )
            )
        }
    }

    /// The dim SHAPE: a conditional opacity where one branch is
    /// fully drawn (`1`) and the other is a fade in 0.2...0.6 —
    /// "sometimes present, sometimes faded", which is what makes
    /// a claim about state.
    ///
    /// Everything else a conditional opacity does in this tree
    /// is decoration and is deliberately out of scope: a hover
    /// wash moves between two fractions (0.12 → 0.18), and an
    /// appear/disappear moves to or from 0. Neither says a
    /// control is inert, so neither owes a reason.
    ///
    /// Matched WITHOUT requiring a leading dot, because
    /// `keybindingRowStyle(inherited:)` calls a bare `opacity(`
    /// inside a `View` extension — the first cut required the
    /// dot and silently missed one of the three dimmers this
    /// suite was written for. And a COLOUR's alpha is not a
    /// view dim: `.tint.opacity(targeted ? 1 : 0.55)` fades a
    /// drop-target highlight's fill, so the receiver is checked
    /// rather than the shape alone.
    private func dimmingOpacity(in source: String) -> Bool {
        var scanned = Substring(source)
        var consumed = 0
        while let call = scanned.range(of: "opacity(") {
            let prefixEnd = source.index(
                source.startIndex,
                offsetBy: consumed
                    + scanned.distance(
                        from: scanned.startIndex,
                        to: call.lowerBound
                    )
            )
            let receiver = String(source[..<prefixEnd].suffix(12))
            let after = scanned[call.upperBound...]
            var depth = 1
            var index = after.startIndex
            var argument = ""
            while index < after.endIndex, depth > 0 {
                let character = after[index]
                if character == "(" { depth += 1 }
                if character == ")" {
                    depth -= 1
                    if depth == 0 { break }
                }
                argument.append(character)
                index = after.index(after: index)
            }
            if argument.contains("?"), isDimPair(argument),
                !isColourAlpha(receiver)
            {
                return true
            }
            consumed += scanned.distance(
                from: scanned.startIndex,
                to: call.upperBound
            )
            scanned = after
        }
        return false
    }

    /// One branch exactly `1`, the other a fade tier.
    private func isDimPair(_ argument: String) -> Bool {
        let numbers = argument.split {
            !$0.isNumber && $0 != "."
        }
        .compactMap { Double($0) }
        guard numbers.contains(1) else { return false }
        return numbers.contains { $0 >= 0.2 && $0 <= 0.6 }
    }

    /// A colour's own alpha rather than a view's. Kept as a
    /// short receiver list rather than a general parser: every
    /// case in this tree is a `Color` or a `ShapeStyle` reached
    /// by name, and a wrong answer here is fail-OPEN (an unseen
    /// dim), so a new spelling joins this list rather than the
    /// list being widened to a guess.
    private func isColourAlpha(_ receiver: String) -> Bool {
        // The receiver arrives with the dot that joins it to the
        // call (`.tint.`), so trim it before comparing.
        let receiver =
            receiver.hasSuffix(".")
            ? String(receiver.dropLast()) : receiver
        for name in [
            ".tint", "Color.primary", "Color.secondary",
            "Color.white", "Color.black", "SettingsTheme",
            ".accent", ".ink",
        ] where receiver.hasSuffix(name) {
            return true
        }
        return false
    }
}
