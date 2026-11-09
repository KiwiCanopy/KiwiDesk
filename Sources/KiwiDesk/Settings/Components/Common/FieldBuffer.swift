/// A text field's typed buffer over a stored value (#3098).
enum FieldBuffer {
    /// Whether the buffer takes an outside change of its value: when
    /// unfocused, or focused and still showing `was` — never
    /// mid-edit, or a background write would discard the user's
    /// partial entry, and a blur would write the old value back.
    static func follows(_ text: String, was: String, focused: Bool) -> Bool {
        !focused || text == was
    }
}
