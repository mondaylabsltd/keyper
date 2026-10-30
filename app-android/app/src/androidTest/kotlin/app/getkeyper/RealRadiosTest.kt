package app.getkeyper

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.provider.Settings
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 2 against the emulator's real radios, with no hook: the screen's own readings of airplane
 * mode, Wi-Fi and the Bluetooth adapter open and close the gate. Shell commands toggle the radios
 * the way the quick settings would.
 */
@RunWith(AndroidJUnit4::class)
class RealRadiosTest {
    @get:Rule val k = KeyperRule(realRadios = true, launch = false)

    private val resolver get() = k.context.contentResolver
    private fun global(name: String) = Settings.Global.getInt(resolver, name, 0)
    private fun bluetoothState() = k.context.getSystemService(BluetoothManager::class.java)?.adapter?.state ?: BluetoothAdapter.STATE_OFF
    private var initial: List<Boolean>? = null

    private fun airplane(on: Boolean) = k.shell("cmd connectivity airplane-mode ${if (on) "enable" else "disable"}")
    private fun wifi(on: Boolean) = k.shell("svc wifi ${if (on) "enable" else "disable"}")
    private fun bluetooth(on: Boolean) = k.shell("cmd bluetooth_manager ${if (on) "enable" else "disable"}")

    @Before
    fun goOffline() {
        initial = listOf(global(Settings.Global.AIRPLANE_MODE_ON) == 1, global(Settings.Global.WIFI_ON) in setOf(1, 2), bluetoothState() != BluetoothAdapter.STATE_OFF)
        airplane(true)
        wifi(false)
        bluetooth(false)
        k.waitFor("radios off", 20_000) {
            global(Settings.Global.AIRPLANE_MODE_ON) == 1 && global(Settings.Global.WIFI_ON) in setOf(0, 3) && bluetoothState() == BluetoothAdapter.STATE_OFF
        }
        k.launch()
        k.awaitOffline(true)
    }

    @After
    fun restoreRadios() {
        val (a, w, b) = initial ?: return
        airplane(a)
        wifi(w)
        bluetooth(b)
    }

    private fun typeSentenceThenExpectOnline(goOnline: () -> Unit) {
        k.focus(R.id.secret)
        k.typeKeys("quiet harbor lanterns")
        goOnline()
        k.waitFor("online", 20_000) { k.shown(R.id.offline_card) && !k.enabled(R.id.secret) }
        assertEquals("", k.text(R.id.secret))
    }

    @Test
    fun turningAirplaneModeOffClosesTheGate() = typeSentenceThenExpectOnline { airplane(false) }

    @Test
    fun turningWifiOnClosesTheGate() = typeSentenceThenExpectOnline { wifi(true) }

    @Test
    fun turningBluetoothOnClosesTheGate() {
        assumeTrue("no Bluetooth adapter on this emulator", k.context.getSystemService(BluetoothManager::class.java)?.adapter != null)
        typeSentenceThenExpectOnline { bluetooth(true) }
    }

    @Test
    fun allRadiosOffAgainReopensIt() {
        typeSentenceThenExpectOnline { airplane(false) }
        airplane(true)
        k.waitFor("offline again", 20_000) { !k.shown(R.id.offline_card) && k.enabled(R.id.secret) }
    }
}
