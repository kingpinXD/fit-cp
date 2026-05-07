package com.example.fit.data

import com.google.firebase.auth.FirebaseAuth

// fit-cp uses Firebase Auth only — RTDB-backed cloud export is dropped in the
// run-up to the Flutter rewrite. exportProgramme still builds local JSON for
// share intents; the cloud upload step is now a no-op.
class FirebaseSyncManager {

    private val auth by lazy { FirebaseAuth.getInstance() }

    val isSignedIn: Boolean
        get() = auth.currentUser != null

    fun exportProgramme(
        @Suppress("UNUSED_PARAMETER") programmeName: String,
        @Suppress("UNUSED_PARAMETER") identifier: String,
        @Suppress("UNUSED_PARAMETER") jsonData: String,
        onComplete: (Boolean) -> Unit
    ) {
        onComplete(isSignedIn)
    }
}
