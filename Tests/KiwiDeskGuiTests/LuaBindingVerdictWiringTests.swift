import Foundation
import Testing

/// A Lua binding row asks Core whether its Lua compiles when the
/// edit is committed — the row appearing, the field losing focus or
/// submitting, the editor closing — and never per keystroke
/// (#2574 ▸ Ruling). The warning reads that verdict alone.
@Suite("Lua binding row verdict wiring (#2574)")
struct LuaBindingVerdictWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir = "Sources/KiwiDesk/Settings/Components/Lua/"

    private func flat(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(Self.dir + file)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("Each commit point asks for the verdict")
    func commitPointsJudge() throws {
        let group = try flat("AdvancedLuaGroup.swift")
        #expect(
            group.occurrences(
                of: ".onChange(of:focusedLua){left,_in"
                    + "ifletleft{judge(left)}}"
            ) == 1
        )
        #expect(
            group.occurrences(
                of: ".onChange(of:editing){closed,_in"
                    + "ifletclosed{judge(closed.id)}}"
            ) == 1
        )
        // A keyboard Save leaves the field focused.
        #expect(
            group.occurrences(
                of: ".onChange(of:model.isDirty){wasDirty,dirtyin"
                    + "ifwasDirty,!dirty,letid=focusedLua{judge(id)}}"
            ) == 1
        )
        let row = try flat("AdvancedLuaGroup+Row.swift")
        #expect(
            row.occurrences(of: ".onAppear{judge(binding.wrappedValue.id)}")
                == 1
        )
        #expect(
            row.occurrences(
                of: ".focused($focusedLua,equals:id).onSubmit{judge(id)}"
            ) == 1
        )
        #expect(row.occurrences(of: "deadWarning(binding.wrappedValue)") == 1)
    }

    /// The judge asks Core, and nothing judges on a text change.
    @Test("The verdict is Core's, never per keystroke")
    func verdictIsCoresAtCommit() throws {
        let verdict = try flat("AdvancedLuaGroup+Verdict.swift")
        #expect(
            verdict.occurrences(of: "model.core.shortcutLuaProblem(lua)") == 1
        )
        for file in [
            "AdvancedLuaGroup.swift", "AdvancedLuaGroup+Row.swift",
            "AdvancedLuaGroup+Verdict.swift",
        ] {
            let source = try flat(file)
            #expect(
                source.occurrences(of: "judge(") == expectedJudges[file],
                "\(file) judges at an unlisted point"
            )
        }
    }

    /// The call sites above plus the declaration.
    private let expectedJudges = [
        "AdvancedLuaGroup.swift": 3,
        "AdvancedLuaGroup+Row.swift": 2,
        "AdvancedLuaGroup+Verdict.swift": 1,
    ]
}
