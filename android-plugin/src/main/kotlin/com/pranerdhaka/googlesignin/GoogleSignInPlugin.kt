package com.pranerdhaka.googlesignin

import android.content.Intent
import androidx.core.content.FileProvider
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File

/**
 * "Sign in with Google" for the game: Android's own account picker
 * (Credential Manager), and back to Godot a Google ID token, which the game
 * hands to Firebase. Signals: signed_in(id_token), sign_in_failed(reason).
 */
class GoogleSignInPlugin(godot: Godot) : GodotPlugin(godot) {

    private val scope = MainScope()

    override fun getPluginName() = "GoogleSignIn"

    override fun getPluginSignals() = setOf(
        SignalInfo("signed_in", String::class.java),
        SignalInfo("sign_in_failed", String::class.java),
        SignalInfo("share_failed", String::class.java),
        SignalInfo("video_ready", String::class.java),
        SignalInfo("video_failed", String::class.java),
    )

    /** Shows the account picker. webClientId: the Firebase project's web client. */
    @UsedByGodot
    fun signIn(webClientId: String) {
        val activity = activity
        if (activity == null) {
            emitSignal("sign_in_failed", "NO_ACTIVITY")
            return
        }
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(GetSignInWithGoogleOption.Builder(webClientId).build())
            .build()
        scope.launch {
            try {
                val result = CredentialManager.create(activity).getCredential(activity, request)
                val credential = result.credential
                if (credential is CustomCredential &&
                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    emitSignal("signed_in", GoogleIdTokenCredential.createFrom(credential.data).idToken)
                } else {
                    emitSignal("sign_in_failed", "UNEXPECTED")
                }
            } catch (e: GetCredentialCancellationException) {
                emitSignal("sign_in_failed", "CANCELLED")
            } catch (e: NoCredentialException) {
                emitSignal("sign_in_failed", "NO_ACCOUNT")
            } catch (e: GetCredentialException) {
                emitSignal("sign_in_failed", "ERROR " + e.type + " " + (e.message ?: ""))
            } catch (e: Exception) {
                emitSignal("sign_in_failed", "ERROR " + e.javaClass.simpleName)
            }
        }
    }

    /**
     * The phone's share sheet with a picture the game drew (a file in its
     * own files folder, under share/) and a line of text: WhatsApp,
     * Facebook, Messenger, saving it, whatever the phone offers.
     */
    @UsedByGodot
    fun shareImage(path: String, text: String) {
        val activity = activity
        if (activity == null) {
            emitSignal("share_failed", "NO_ACTIVITY")
            return
        }
        activity.runOnUiThread {
            try {
                val uri = FileProvider.getUriForFile(activity, activity.packageName + ".pranerdhaka.share", File(path))
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val chooser = Intent.createChooser(send, null)
                chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                activity.startActivity(chooser)
            } catch (e: Exception) {
                emitSignal("share_failed", e.javaClass.simpleName)
            }
        }
    }

    /**
     * Makes the day's reel: the frames the game drew (dir/f000.png, ...)
     * and a piece of music (raw 16-bit mono PCM at sampleRate) into an MP4,
     * on a thread of its own. Signals video_ready(path) or video_failed(why).
     */
    @UsedByGodot
    fun makeVideo(dir: String, count: Int, fps: Int, audioPath: String, sampleRate: Int, outPath: String) {
        Thread {
            try {
                ReelEncoder.encode(dir, count, fps, audioPath, sampleRate, outPath)
                emitSignal("video_ready", outPath)
            } catch (e: Exception) {
                emitSignal("video_failed", e.javaClass.simpleName + ": " + (e.message ?: ""))
            }
        }.start()
    }

    /** The phone's share sheet with a video the game made (under share/). */
    @UsedByGodot
    fun shareVideo(path: String, text: String) {
        val activity = activity
        if (activity == null) {
            emitSignal("share_failed", "NO_ACTIVITY")
            return
        }
        activity.runOnUiThread {
            try {
                val uri = FileProvider.getUriForFile(activity, activity.packageName + ".pranerdhaka.share", File(path))
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "video/mp4"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val chooser = Intent.createChooser(send, null)
                chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                activity.startActivity(chooser)
            } catch (e: Exception) {
                emitSignal("share_failed", e.javaClass.simpleName)
            }
        }
    }
}

/** Its own class, so its entry cannot clash with another FileProvider's. */
class ShareFileProvider : FileProvider()
