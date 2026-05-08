package com.example.fit.data

import com.google.firebase.auth.FirebaseAuth

// fit-cp uses Firebase Auth only — RTDB-backed cloud export is dropped in the
// run-up to the Flutter rewrite. exportProgramme still builds local JSON for
// share intents; the cloud upload step is now a no-op.
//
// `authProvider` is a lazy supplier so the default `FirebaseAuth.getInstance()`
// call (which fails in Robolectric without FirebaseApp init) is deferred until
// it's actually needed. Tests inject a fixed value via the convenience overload.
class FirebaseSyncManager(
    private val authProvider: () -> FirebaseAuth = { FirebaseAuth.getInstance() }
) {

    /** Test-friendly constructor that takes a pre-built [FirebaseAuth] directly. */
    constructor(auth: FirebaseAuth) : this({ auth })

    private val auth: FirebaseAuth by lazy { authProvider() }

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
