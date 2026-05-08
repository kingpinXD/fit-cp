package com.example.fit.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

/**
 * Unit tests for [FirebaseSyncManager]. Mocks the injected [FirebaseAuth] so we
 * never touch real Firebase — sign-in state and the export callback are driven
 * entirely from `currentUser`.
 */
class FirebaseSyncManagerTest {

    @Test
    fun `isSignedIn returns true when currentUser is not null`() {
        val auth = mock<FirebaseAuth>()
        whenever(auth.currentUser).thenReturn(mock<FirebaseUser>())

        val manager = FirebaseSyncManager(auth)
        assertTrue(manager.isSignedIn)
    }

    @Test
    fun `isSignedIn returns false when currentUser is null`() {
        val auth = mock<FirebaseAuth>()
        whenever(auth.currentUser).thenReturn(null)

        val manager = FirebaseSyncManager(auth)
        assertFalse(manager.isSignedIn)
    }

    @Test
    fun `exportProgramme calls onComplete with true when signed in`() {
        val auth = mock<FirebaseAuth>()
        whenever(auth.currentUser).thenReturn(mock<FirebaseUser>())
        val manager = FirebaseSyncManager(auth)

        var captured: Boolean? = null
        manager.exportProgramme("name", "id", "{}") { captured = it }

        assertEquals(true, captured)
    }

    @Test
    fun `exportProgramme calls onComplete with false when signed out`() {
        val auth = mock<FirebaseAuth>()
        whenever(auth.currentUser).thenReturn(null)
        val manager = FirebaseSyncManager(auth)

        var captured: Boolean? = null
        manager.exportProgramme("name", "id", "{}") { captured = it }

        assertEquals(false, captured)
    }
}
