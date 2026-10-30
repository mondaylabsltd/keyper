package app.getkeyper

import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 1: Keyper requests no permission at all, as the installed package reports it. The clipboard
 * job (Android 8 and 9) is protected by BIND_JOB_SERVICE, which only the system holds; it is not a
 * permission Keyper requests.
 */
@RunWith(AndroidJUnit4::class)
class NoPermissionsTest {
    @Test
    fun theInstalledAppRequestsNoPermission() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        assertEquals(emptyList<String>(), info.requestedPermissions?.toList().orEmpty())
    }
}
