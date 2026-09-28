import KiwiDeskCore

extension GapsEditor {
    /// The pointer to the looks, which write the gaps (#1739).
    static var lookReference: String {
        L(
            "gaps.looks_xref",
            "A look sets these gaps and the focus border's width, "
                + "corners and glow in one click — in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }
}
