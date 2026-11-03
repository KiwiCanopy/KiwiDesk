import Foundation

/// Core's doors onto `LibraryNameVerdict` (#2953): the GUI asks them
/// for a typed name, and the save and rename doors refuse through
/// them before they write.
extension KiwiCore {
    /// The verdict on `typed`, trimmed, as a palette name; pass
    /// `renaming` the palette's current name for a rename.
    public func paletteNameVerdict(
        _ typed: String,
        renaming old: String? = nil
    ) -> LibraryNameVerdict {
        let library = paletteLibrary
        return LibraryNameVerdict.judge(
            LibraryNameVerdict.normalized(typed),
            renaming: old,
            bundled: library.isBuiltinName,
            saved: library.hasUserPalette
        )
    }

    /// The verdict on `typed`, trimmed, as a look name; pass
    /// `renaming` the look's current name for a rename.
    public func lookNameVerdict(
        _ typed: String,
        renaming old: String? = nil
    ) -> LibraryNameVerdict {
        let library = lookLibrary
        return LibraryNameVerdict.judge(
            LibraryNameVerdict.normalized(typed),
            renaming: old,
            bundled: library.isBuiltinName,
            saved: library.hasUserLook
        )
    }

    /// `typed` trimmed, the name a write stores, once `verdict`
    /// allows it; else throws `LibraryNameRefusal`.
    func admittedName(
        _ typed: String,
        _ verdict: LibraryNameVerdict
    ) throws -> String {
        guard verdict.isAllowed else {
            throw LibraryNameRefusal(verdict: verdict)
        }
        return LibraryNameVerdict.normalized(typed)
    }
}
