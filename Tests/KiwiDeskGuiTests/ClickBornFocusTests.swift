import Foundation
import Testing

@testable import KiwiDesk

/// The #1309 arm on `ClickBornFocus`, held at both its answers
/// and at both values of the choice that reaches it.
///
/// The claim: a container's `.focused($x)` reads "focus is
/// WITHIN me", so the refusal cannot tell its own ring from the
/// caret a click just put in a field inside it — and only the
/// caller knows which of the two it is. The argument, its device
/// log and its negative control are on #1309.
///
/// These pin the DECISION, never the live read: that needs an
/// `NSApplication` and a key window, which no test host has.
/// Measured residue (`guard-prover`, 2026-09-07, under a full
/// 4855-test run): gutting `textEditingOwnsFocus` to `false`
/// reds NOTHING here or anywhere in the suite, so the green
/// below covers the decision and its wiring and not whether the
/// live read identifies a field editor.
@Suite("A click that starts text editing is not a stray ring")
struct ClickBornFocusTests {
    @Test("a container withholds the refusal, however clicked")
    func editingNeverRefused() {
        for held in [true, false] {
            for dispatching in [true, false] {
                #expect(
                    ClickBornFocus.refuses(
                        mouseHeld: held,
                        dispatchingMouseEvent: dispatching,
                        focusMayBeADescendant: true,
                        textEditingOwnsFocus: true
                    ) == false
                )
            }
        }
    }

    /// The other value of the choice, and the reason it is the
    /// caller's: a leaf control cannot be confused by a
    /// descendant, so the arm must be unreachable for it rather
    /// than merely unlikely — #991's ring survives even while
    /// something else in the key window is being typed into.
    @Test("a leaf control still refuses while text is edited")
    func leafRefusesDespiteEditing() {
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: true,
                dispatchingMouseEvent: false,
                focusMayBeADescendant: false,
                textEditingOwnsFocus: true
            )
        )
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: false,
                dispatchingMouseEvent: true,
                focusMayBeADescendant: false,
                textEditingOwnsFocus: true
            )
        )
    }

    /// Or the arms above would pass on a function that refuses
    /// nothing at all — the symmetric deletion `guard-prover`
    /// measured this suite against.
    @Test("either mouse reading alone still refuses")
    func mouseStillRefused() {
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: true,
                dispatchingMouseEvent: false,
                focusMayBeADescendant: true,
                textEditingOwnsFocus: false
            )
        )
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: false,
                dispatchingMouseEvent: true,
                focusMayBeADescendant: true,
                textEditingOwnsFocus: false
            )
        )
    }

    /// #991 allows programmatic focus, and #996's arrival ring
    /// is exactly that.
    @Test("a focus change with no mouse behind it stands")
    func programmaticFocusStands() {
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: false,
                dispatchingMouseEvent: false,
                focusMayBeADescendant: true,
                textEditingOwnsFocus: false
            ) == false
        )
    }

    /// The wiring, not the function. Gut the live property's
    /// argument to a literal and every assertion above stays
    /// green while the defect returns whole.
    ///
    /// Read against `isClickBorn`'s own brace-balanced body, not
    /// the file: `guard-prover` (2026-09-07) satisfied a
    /// file-wide needle twice with the defect fully live — once
    /// by shadowing the property with a local `false`, once by
    /// adding an uncalled neighbour that did pass the read. That
    /// is the class `tests.md` names against `WorkflowSource`
    /// ▸ #968.
    @Test("the refusal is wired to the live text-editing read")
    func refusalIsWiredToTheLiveRead() throws {
        let body = try Self.isClickBornBody()
        for argument in [
            "focusMayBeADescendant:focusMayBeADescendant",
            "textEditingOwnsFocus:textEditingOwnsFocus",
        ] {
            #expect(
                body.contains(argument),
                Comment(
                    rawValue:
                        "`isClickBorn` no longer hands `refuses` "
                        + "`\(argument)`, so the #1309 arm cannot "
                        + "fire however the pure function is "
                        + "written. Pass it, never a literal."
                )
            )
        }
    }

    /// Every focusable Settings control STATES which of the two
    /// it is, and the population is derived rather than listed —
    /// `ArrivalRingTests.clickRefusalCensus`' idiom, which holds
    /// the same files to consulting this predicate at all. A new
    /// `.focusable()` control reds here until someone rules its
    /// value, which is the whole point of moving the choice onto
    /// the call.
    @Test("each focusable control rules its own container-ness")
    func everyConsumerStatesTheChoice() throws {
        let ruled = [
            "SettingsView+Detail.swift": "true",
            "SpaceAssignmentChip.swift": "false",
            "SettingsSlider.swift": "false",
            "SegmentedPicker.swift": "false",
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        var seen: [String] = []
        for file in files {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
            guard source.contains("ClickBornFocus.isClickBorn")
            else { continue }
            seen.append(name)
            let value = try #require(
                ruled[name],
                Comment(
                    rawValue:
                        "\(name) consults `ClickBornFocus` and "
                        + "is not ruled here. Say whether its "
                        + "focus can land on a DESCENDANT — a "
                        + "container passes true, a leaf false."
                )
            )
            #expect(
                source.contains(
                    "focusMayBeADescendant:\(value)"
                ),
                Comment(
                    rawValue:
                        "\(name) no longer passes "
                        + "`focusMayBeADescendant: \(value)`."
                )
            )
        }
        #expect(seen.sorted() == ruled.keys.sorted())
    }

    /// `isClickBorn`'s body, brace-balanced from its own
    /// declaration so a neighbour can neither satisfy nor break
    /// the clause above.
    private static func isClickBornBody() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "ClickBornFocus.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        let marker = "staticfuncisClickBorn("
        let start = try #require(
            source.range(of: marker),
            Comment(
                rawValue:
                    "`isClickBorn` is no longer declared as a "
                    + "function taking the container choice."
            )
        )
        var cursor = Array(source[start.upperBound...])
        var index = 0
        _ = SourceScan.balanced(
            cursor,
            from: &index,
            open: "(",
            close: ")"
        )
        cursor = Array(cursor[index...])
        var bodyCursor = 0
        // Skip the return type between `)` and the body brace.
        while bodyCursor < cursor.count,
            cursor[bodyCursor] != "{"
        {
            bodyCursor += 1
        }
        return try #require(
            SourceScan.balanced(
                cursor,
                from: &bodyCursor,
                open: "{",
                close: "}"
            ),
            Comment(
                rawValue:
                    "`isClickBorn` has no brace-balanced body."
            )
        )
    }
}
