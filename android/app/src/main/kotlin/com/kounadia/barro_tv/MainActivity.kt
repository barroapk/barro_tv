package com.kounadia.barro_tv

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Build
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Partie Android de Barro Play : luminosité, volume, superposition (PiP),
// écran toujours allumé et ouverture des vidéos du téléphone.
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var lienExterne: String? = null
    private var pipAutorise = false
    private var ratio = 1.777

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        lienExterne = lireLien(intent)
        val c = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "barro/lecteur")
        canal = c
        c.setMethodCallHandler { call, result ->
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            when (call.method) {
                "lienExterne" -> {
                    result.success(lienExterne)
                    lienExterne = null
                }
                "luminosite" -> {
                    val v = window.attributes.screenBrightness
                    result.success(if (v < 0) -1.0 else v.toDouble())
                }
                "setLuminosite" -> {
                    val lp = window.attributes
                    lp.screenBrightness = (call.argument<Double>("v") ?: -1.0).toFloat()
                    window.attributes = lp
                    result.success(null)
                }
                "volume" -> result.success(
                    if (max > 0) audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max else 0.5
                )
                "setVolume" -> {
                    val v = ((call.argument<Double>("v") ?: 0.0) * max).toInt().coerceIn(0, max)
                    audio.setStreamVolume(AudioManager.STREAM_MUSIC, v, 0)
                    result.success(null)
                }
                "eveil" -> {
                    if (call.argument<Boolean>("v") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "autoriserPip" -> {
                    pipAutorise = call.argument<Boolean>("v") ?: false
                    ratio = call.argument<Double>("ratio") ?: ratio
                    result.success(null)
                }
                "pip" -> {
                    ratio = call.argument<Double>("ratio") ?: ratio
                    result.success(entrerPip())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun entrerPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val r = Rational((ratio * 1000).toInt().coerceIn(420, 2390), 1000)
            enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(r).build())
        } catch (e: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipAutorise) entrerPip()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        canal?.invokeMethod("pip", isInPictureInPictureMode)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val l = lireLien(intent)
        if (l != null) canal?.invokeMethod("ouvrir", l)
    }

    private fun lireLien(i: Intent?): String? =
        if (i?.action == Intent.ACTION_VIEW) i.data?.toString() else null
}
