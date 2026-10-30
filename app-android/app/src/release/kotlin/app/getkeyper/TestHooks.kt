package app.getkeyper

/**
 * The release counterpart of src/debug/.../TestHooks.kt: every hook is a constant null, so the
 * app always reads the real radios, runs the real derivation and keeps the real clipboard timer.
 * R8 inlines these getters and removes the branches that would use a hook.
 */
internal object TestHooks {
    val radios: (() -> List<Boolean>)? get() = null
    val derive: ((email: String, secret: String) -> ByteArray)? get() = null
    val clipboardMs: Long? get() = null
    val suppressClipboardOverlay: Boolean? get() = null
    @Suppress("UNUSED_PARAMETER") fun log(message: String) {}
}
