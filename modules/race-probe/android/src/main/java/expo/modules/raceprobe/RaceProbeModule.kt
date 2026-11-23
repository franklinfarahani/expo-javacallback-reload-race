package expo.modules.raceprobe

import android.content.Context
import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.util.concurrent.Executors
import java.util.concurrent.ThreadLocalRandom
import java.util.concurrent.TimeUnit

private val resolvers = Executors.newScheduledThreadPool(4)

private val payload = "x".repeat(1 shl 20)

class RaceProbeModule : Module() {
  private val prefs
    get() = appContext.reactContext!!.getSharedPreferences("race-probe", Context.MODE_PRIVATE)

  override fun definition() = ModuleDefinition {
    Name("RaceProbe")

    AsyncFunction("pending") { promise: Promise ->
      val delay = ThreadLocalRandom.current().nextLong(0, 200_000)
      resolvers.schedule({ promise.resolve(payload) }, delay, TimeUnit.MICROSECONDS)
    }

    Function("nextReload") {
      val n = prefs.getInt("reloads", 0) + 1
      prefs.edit().putInt("reloads", n).commit()
      Log.i("RaceProbe", "reload $n")
      n
    }

    Function("resetReloads") {
      prefs.edit().putInt("reloads", 0).commit()
    }
  }
}
