import Testing

@testable import KiwiDeskCore

/// Every path a look carries has a command that sets it (#1685),
/// so an AI app reading `look.current` can change any one value.
/// A look path added without its setter, or a setter renamed away
/// from the path's spelling, reds here.
@Suite("Look setter census")
struct LookSetterCensusTests {
    @Test("every look and colour path names a dispatchable setter")
    func everyPathHasASetter() {
        let paths = LookKeys.all + ColorPaletteKeys.all
        #expect(!paths.isEmpty)
        for path in paths {
            let setter = APIReference.lookSetter(for: path)
            #expect(setter != nil, "\(path) has no setter")
            if let setter {
                #expect(APIReference.dispatchable.contains(setter))
            }
        }
    }

    @Test("a path is spelled as its namespace's set_ verb")
    func setterSpelling() {
        #expect(
            APIReference.lookSetter(for: "drag.ghost.fill_color")
                == "drag.set_ghost_fill_color"
        )
        #expect(
            APIReference.lookSetter(for: "gap.global")
                == "set_gap_global"
        )
        #expect(APIReference.lookSetter(for: "nope.thing") == nil)
    }
}
