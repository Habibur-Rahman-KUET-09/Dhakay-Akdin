package com.pranerdhaka.googlesignin

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
                emitSignal("sign_in_failed", "ERROR " + e.type)
            } catch (e: Exception) {
                emitSignal("sign_in_failed", "ERROR " + e.javaClass.simpleName)
            }
        }
    }
}
