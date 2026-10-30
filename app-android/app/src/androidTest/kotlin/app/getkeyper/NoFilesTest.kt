package app.getkeyper

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Claim 3: after a real derivation, with the phrase shown and copied, Keyper has written no file,
 * shared preference or database anywhere in its data directories.
 *
 * This is the one test that runs the real 1 GiB Argon2id (no derivation hook), so that the off-heap
 * mapping is exercised too: it takes about a minute on an emulator and needs one with 3 GB of RAM or
 * more. Every other test uses a fake derivation, which is honest for what they check: the screen
 * logic around the derivation, which is identical either way.
 */
@RunWith(AndroidJUnit4::class)
class NoFilesTest {
    @get:Rule val k = KeyperRule(realDerivation = true)

    /** Created and maintained by ART for every app (JIT profiles, test agents), not by Keyper. */
    private val systemManaged = setOf("code_cache")

    private fun filesUnder(root: File): List<String> =
        root.walkTopDown()
            .onEnter { it == root || it.relativeTo(root).invariantSeparatorsPath.substringBefore('/') !in systemManaged }
            .filter { it.isFile }
            .map { it.path }
            .toList()

    @Test(timeout = 15 * 60_000)
    fun aRealDerivationLeavesNoFiles() {
        k.fillInputs()
        k.tap(R.id.generate)
        val phrase = k.awaitPhrase(12, timeoutMs = 14 * 60_000)
        k.copy()
        assertEquals(phrase.joinToString(" "), k.clipText())

        val context = k.context
        val roots = listOf(context.dataDir, context.createDeviceProtectedStorageContext().dataDir)
        for (root in roots) {
            assertTrue("$root missing", root.isDirectory)
            assertEquals("files under $root", emptyList<String>(), filesUnder(root))
            for (dir in listOf("files", "shared_prefs", "databases", "no_backup")) {
                val d = File(root, dir)
                assertTrue("$d holds ${d.list()?.toList()}", !d.exists() || d.list().isNullOrEmpty())
            }
        }
        // Shared storage: the shell can look where the app has no permission to.
        val pkg = context.packageName
        for (dir in listOf("data", "obb")) {
            val listing = k.shell("ls -a /sdcard/Android/$dir/$pkg").trim()
            assertTrue("/sdcard/Android/$dir/$pkg: $listing", listing.isEmpty() || "No such file" in listing || listing.lines().all { it == "." || it == ".." })
        }
    }
}
