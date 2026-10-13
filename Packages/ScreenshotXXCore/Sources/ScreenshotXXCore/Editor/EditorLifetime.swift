/// When an editor (its window, image and undo history) can be freed.
/// Unsaved edits are kept while the Quick Access card can still reopen them with Edit.
public enum EditorLifetime {
    public static func shouldRelease(windowIsOpen: Bool, hasUnsavedEdits: Bool, cardIsOpen: Bool) -> Bool {
        !windowIsOpen && (!hasUnsavedEdits || !cardIsOpen)
    }
}
