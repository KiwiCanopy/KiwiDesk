import Foundation
import Testing

@testable import KiwiDesk

/// **The accessory slot stays a control of its own** (#956) —
/// split from `SettingsDisclosureHeaderTests`, which was one
/// line off the 350-line hard ceiling before this moved
/// (code review, 2026-08-26), and which owns what the header
/// row IS. This owns the one ruling about what sits BESIDE it.
///
/// The standing limit of that suite applies here unchanged:
/// every assertion is a token match over squashed source, so a
/// green means "the pieces are still declared", never "the row
/// is clickable end to end". #956's eye-confirm on device is
/// part of the change, not a nicety.
///
/// Note the two slots are not the same thing and are guarded
/// apart: `accessory:` takes a VIEW and may be a control, so it
/// is a sibling of the button; `summary:` takes a STRING and
/// rides inside it, which `SettingsDisclosureSizeTests` owns.
@Suite("Settings disclosure accessory")
struct SettingsDisclosureAccessoryTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    private static let styleFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosureStyle.swift"

    private static let wrapperFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosure.swift"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = Self.root.appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The accessory slot may hold a CONTROL — `DesktopsGroup`
    /// puts a `HelpButton` there — so it must be a sibling of the
    /// header button, never inside its label. Nested, its click
    /// toggled the drawer and its name and hint collapsed into
    /// the header's one element (code + architect review,
    /// 2026-08-24).
    @Test("the accessory sits beside the button, not inside it")
    func accessoryIsNotNestedInTheButton() throws {
        let style = try squashed(Self.styleFile)
        // The button's label run, taken by BRACE MATCHING
        // rather than by a substring near it. The first draft
        // of this test asked for `)accessory()}`, which
        // re-nesting the accessory after the `Spacer` also
        // satisfies — the guard was green with the blocker back
        // (code review, 2026-08-24). What has to be true is
        // positional, so the assertion has to be positional.
        let label = try buttonLabelRun(style)
        // Non-vacuity: this really is the label's run.
        #expect(label.contains("configuration.label"))
        #expect(label.contains("Spacer(minLength:0)"))
        #expect(
            !label.contains("accessory()"),
            Comment(
                rawValue:
                    "the accessory is inside the header "
                    + "button's label — a control nested in a "
                    + "control loses its own hit target and its "
                    + "own announcement (#956)"
            )
        )
        // And it is still drawn at all, beside the button.
        #expect(style.contains("accessory()"))
        // And the wrapper must not put it back in the label.
        let wrapper = try squashed(Self.wrapperFile)
        // ANCHORED to the style call's own argument list, not
        // two free-floating needles. Loosening the exact pin was
        // right — the argument list is not the invariant, and it
        // redded on a `summary:` parameter that has nothing to
        // do with this ruling — but unanchored it lost what the
        // pin had: guard-prover made the style call take
        // `accessory: { EmptyView() }` AND added a plausible
        // forwarding init spelling `accessory: accessory)`
        // elsewhere in the file, and every test passed with the
        // accessory never reaching the style (2026-08-26).
        let styleCall = try parenthesised(
            after: ".disclosureGroupStyle",
            in: wrapper
        )
        #expect(styleCall.contains("SettingsDisclosureStyle("))
        #expect(
            styleCall.contains("accessory:accessory"),
            Comment(
                rawValue:
                    "the accessory no longer reaches the style "
                    + "as its own argument — \(styleCall)"
            )
        )
        // And the wrapper must not put it back in the label.
        // The needle this replaces named `labelFont`, deleted in
        // #1021 and now asserted GONE by the sibling suite — a
        // canary that could never match, so re-nesting
        // `accessory()` in the `DisclosureGroup` label shipped
        // green (code review, 2026-08-26). Read the label's own
        // run instead, the way the style-side clause above does.
        let wrapperLabel = try buttonLabelRun(wrapper)
        #expect(wrapperLabel.contains("Text(control.text)"))
        #expect(
            !wrapperLabel.contains("accessory"),
            Comment(
                rawValue:
                    "the accessory is back inside the "
                    + "DisclosureGroup label, which the style "
                    + "wraps in a Button — \(wrapperLabel)"
            )
        )
    }

    /// The balanced parentheses following `marker`, so a clause
    /// reads ONE call's arguments rather than the whole file.
    private func parenthesised(
        after marker: String,
        in squashed: String
    ) throws -> String {
        let characters = Array(squashed)
        let head = try #require(
            squashed.range(of: marker),
            "`\(marker)` is gone"
        )
        var cursor = squashed.distance(
            from: squashed.startIndex,
            to: head.upperBound
        )
        return try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ),
            "`\(marker)` has no argument list"
        )
    }

    /// The content of the header `Button`'s `label:` closure,
    /// by brace matching over the squashed source.
    private func buttonLabelRun(_ style: String) throws -> String {
        let text = Array(style)
        let marker = Array("label:")
        var start: Int? = nil
        for i in 0...(max(text.count - marker.count, 0))
        where Array(text[i..<min(i + marker.count, text.count)])
            == marker
        {
            start = i
            break
        }
        var cursor =
            try #require(
                start,
                "the style has no `label:` closure any more"
            ) + marker.count
        return try #require(
            SourceScan.balanced(
                text,
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "the `label:` closure does not close"
        )
    }
}
