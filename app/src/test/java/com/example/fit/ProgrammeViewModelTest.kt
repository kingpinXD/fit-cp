package com.example.fit

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.lifecycle.LiveData
import androidx.lifecycle.Observer
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.example.fit.data.AppDatabase
import com.example.fit.data.Exercise
import com.example.fit.data.ExerciseLog
import com.example.fit.data.ImportResult
import com.example.fit.data.Programme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Behavioural tests for ProgrammeViewModel. Exercises the full LiveData wiring
 * (week/day/exercise reactive chain), import flow, log mutation, and reset on delete.
 *
 * Trivial wrappers intentionally untested: each LiveData passthrough on the
 * ViewModel (e.g. the `selectedWeek == null` else-branches in switchMap) is a
 * one-liner returning `MutableLiveData(emptyList())`. The reactive chain is
 * covered by `selecting only week without day yields empty exercises` and
 * the initial-state tests; per-branch coverage of these fallbacks adds noise
 * without testing real behaviour, so they are left as-is.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = FitApp::class)
class ProgrammeViewModelTest {

    @get:Rule
    val instantTaskRule = InstantTaskExecutorRule()

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var viewModel: ProgrammeViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        // Replace the AppDatabase singleton with an in-memory build that allows
        // main-thread queries — the test dispatcher runs on the main thread.
        installInMemoryDatabase()
        clearPrefs()
        viewModel = ProgrammeViewModel(ApplicationProvider.getApplicationContext())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // --- Initial state ---

    @Test
    fun `initial state - no programme means hasProgramme false`() = runTest(testDispatcher) {
        advanceUntilIdle()
        assertEquals(false, viewModel.hasProgramme.observeOnce())
        assertEquals(emptyList<Int>(), viewModel.weeks.observeOnce())
        assertEquals(emptyList<Int>(), viewModel.completedWeeks.observeOnce())
        assertEquals("", viewModel.programmeName.value)
    }

    @Test
    fun `initial state - selectedWeek null gives no day stream value`() = runTest(testDispatcher) {
        advanceUntilIdle()
        // selectedWeek has no value yet, so its switchMap never fires.
        assertNull(viewModel.days.observeOnce())
        assertNull(viewModel.completedDays.observeOnce())
    }

    @Test
    fun `initial state - no exercise selected gives null log and empty history`() =
        runTest(testDispatcher) {
            advanceUntilIdle()
            // selectedExercise is null and switchMap never fires so both streams have no value.
            assertNull(viewModel.selectedExerciseLog.observeOnce())
            assertNull(viewModel.exerciseHistory.observeOnce())
        }

    // --- Import ---

    @Test
    fun `importProgramme - sets programme name and exposes weeks`() = runTest(testDispatcher) {
        var result: ImportResult? = null
        viewModel.importProgramme(SAMPLE_JSON, "test_prog") { result = it }
        advanceUntilIdle()

        assertEquals(ImportResult.IMPORTED, result)
        assertEquals("test_prog", viewModel.programmeName.value)
        assertEquals(true, viewModel.hasProgramme.observeOnce())
        assertEquals(listOf(1, 2), viewModel.weeks.observeOnce())
    }

    @Test
    fun `importProgramme twice with same name - second is SWITCHED`() = runTest(testDispatcher) {
        var first: ImportResult? = null
        var second: ImportResult? = null
        viewModel.importProgramme(SAMPLE_JSON, "test_prog") { first = it }
        advanceUntilIdle()
        viewModel.importProgramme(SAMPLE_JSON, "test_prog") { second = it }
        advanceUntilIdle()

        assertEquals(ImportResult.IMPORTED, first)
        assertEquals(ImportResult.SWITCHED, second)
    }

    @Test
    fun `importProgramme with malformed JSON - callback not invoked, no crash`() =
        runTest(testDispatcher) {
            var invoked = false
            viewModel.importProgramme("{not json", "broken") { invoked = true }
            advanceUntilIdle()

            assertFalse("Failure path should swallow exception, not propagate", invoked)
            assertEquals("", viewModel.programmeName.value)
        }

    // --- Reactive wiring ---

    @Test
    fun `selecting week exposes its days`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()

        viewModel.selectedWeek.value = 1
        advanceUntilIdle()
        assertEquals(listOf("Day A", "Day B"), viewModel.days.observeOnce())

        viewModel.selectedWeek.value = 2
        advanceUntilIdle()
        assertEquals(listOf("Day A"), viewModel.days.observeOnce())
    }

    @Test
    fun `selecting week and day exposes exercises in order`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()

        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()

        val exercises = viewModel.exercises.observeOnce()!!
        assertEquals(2, exercises.size)
        assertEquals(listOf("Squat", "Bench"), exercises.map { it.exerciseName })
        assertEquals(listOf(0, 1), exercises.map { it.orderIndex })
    }

    @Test
    fun `selecting only week without day yields empty exercises`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        advanceUntilIdle()

        assertTrue(viewModel.exercises.observeOnce()!!.isEmpty())
        assertTrue(viewModel.exerciseLogs.observeOnce()!!.isEmpty())
    }

    @Test
    fun `selectedExercise updates log and history streams`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 2
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()

        val ex = viewModel.exercises.observeOnce()!!.first()
        viewModel.selectedExercise.value = ex
        advanceUntilIdle()

        // No log yet
        assertNull(viewModel.selectedExerciseLog.observeOnce())
        // No history yet (no logs written for prior weeks)
        assertTrue(viewModel.exerciseHistory.observeOnce()!!.isEmpty())
    }

    // --- Mark done / skipped ---

    @Test
    fun `markDone writes a DONE log with provided weight and rpe`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()
        val ex = viewModel.exercises.observeOnce()!!.first()

        viewModel.markDone(ex, weight = "100", equipment = "Barbell", comments = "felt good", observedRpe = "9")
        advanceUntilIdle()

        viewModel.selectedExercise.value = ex
        advanceUntilIdle()
        val log = viewModel.selectedExerciseLog.observeOnce()
        assertNotNull(log)
        assertEquals("100", log!!.userWeight)
        assertEquals("Barbell", log.equipmentType)
        assertEquals("felt good", log.userComments)
        assertEquals("9", log.observedRpe)
        assertEquals("DONE", log.status)
    }

    @Test
    fun `markDone with blank rpe falls back to exercise default rpe`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()
        val ex = viewModel.exercises.observeOnce()!!.first { it.exerciseName == "Squat" }

        viewModel.markDone(ex, weight = "120", equipment = "", comments = "", observedRpe = "")
        advanceUntilIdle()

        viewModel.selectedExercise.value = ex
        advanceUntilIdle()
        // SAMPLE_JSON sets Squat rpe = "8-9" so blank observedRpe should fall through.
        assertEquals("8-9", viewModel.selectedExerciseLog.observeOnce()!!.observedRpe)
    }

    @Test
    fun `markDone twice on same exercise replaces existing log`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()
        val ex = viewModel.exercises.observeOnce()!!.first()

        viewModel.markDone(ex, "100", "", "", "8")
        advanceUntilIdle()
        viewModel.markDone(ex, "110", "", "", "9")
        advanceUntilIdle()

        viewModel.selectedExercise.value = ex
        advanceUntilIdle()
        val log = viewModel.selectedExerciseLog.observeOnce()!!
        assertEquals("110", log.userWeight)
        assertEquals("9", log.observedRpe)
    }

    @Test
    fun `markSkipped writes a SKIPPED log with empty fields`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        advanceUntilIdle()
        val ex = viewModel.exercises.observeOnce()!!.first()

        viewModel.markSkipped(ex)
        advanceUntilIdle()

        viewModel.selectedExercise.value = ex
        advanceUntilIdle()
        val log = viewModel.selectedExerciseLog.observeOnce()!!
        assertEquals("SKIPPED", log.status)
        assertEquals("", log.userWeight)
        assertEquals("", log.observedRpe)
    }

    // --- Completion tracking ---

    @Test
    fun `marking every exercise in a day done lists day as completed`() =
        runTest(testDispatcher) {
            viewModel.importProgramme(SAMPLE_JSON, "test_prog")
            advanceUntilIdle()
            viewModel.selectedWeek.value = 1
            viewModel.selectedDay.value = "Day A"
            advanceUntilIdle()

            val exercises = viewModel.exercises.observeOnce()!!
            for (ex in exercises) {
                viewModel.markDone(ex, "100", "", "", "8")
            }
            advanceUntilIdle()

            assertEquals(listOf("Day A"), viewModel.completedDays.observeOnce())
        }

    @Test
    fun `marking only some exercises in a day - day not yet complete`() =
        runTest(testDispatcher) {
            viewModel.importProgramme(SAMPLE_JSON, "test_prog")
            advanceUntilIdle()
            viewModel.selectedWeek.value = 1
            viewModel.selectedDay.value = "Day A"
            advanceUntilIdle()

            val first = viewModel.exercises.observeOnce()!!.first()
            viewModel.markDone(first, "100", "", "", "8")
            advanceUntilIdle()

            assertTrue(viewModel.completedDays.observeOnce()!!.isEmpty())
        }

    @Test
    fun `completing every day in a week lists week as completed`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()

        // Week 1 has Day A + Day B; mark all exercises in both done.
        for (day in listOf("Day A", "Day B")) {
            viewModel.selectedWeek.value = 1
            viewModel.selectedDay.value = day
            advanceUntilIdle()
            for (ex in viewModel.exercises.observeOnce()!!) {
                viewModel.markDone(ex, "100", "", "", "8")
            }
            advanceUntilIdle()
        }

        assertEquals(listOf(1), viewModel.completedWeeks.observeOnce())
    }

    @Test
    fun `history surfaces logs from earlier weeks for same exercise name`() =
        runTest(testDispatcher) {
            viewModel.importProgramme(SAMPLE_JSON, "test_prog")
            advanceUntilIdle()
            viewModel.selectedWeek.value = 1
            viewModel.selectedDay.value = "Day A"
            advanceUntilIdle()
            val w1Squat = viewModel.exercises.observeOnce()!!.first { it.exerciseName == "Squat" }
            viewModel.markDone(w1Squat, "100", "Barbell", "wk1", "8")
            advanceUntilIdle()

            // Now look at week 2's Squat — history should show week 1.
            viewModel.selectedWeek.value = 2
            viewModel.selectedDay.value = "Day A"
            advanceUntilIdle()
            val w2Squat = viewModel.exercises.observeOnce()!!.first { it.exerciseName == "Squat" }
            viewModel.selectedExercise.value = w2Squat
            advanceUntilIdle()

            val history = viewModel.exerciseHistory.observeOnce()!!
            assertEquals(1, history.size)
            assertEquals(1, history.first().weekNumber)
            assertEquals("100", history.first().userWeight)
        }

    // --- switchProgramme / deleteProgramme ---

    @Test
    fun `switchProgramme updates active programme name`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "first")
        advanceUntilIdle()
        viewModel.importProgramme(SAMPLE_JSON_TWO, "second")
        advanceUntilIdle()

        viewModel.switchProgramme("first")
        advanceUntilIdle()

        assertEquals("first", viewModel.programmeName.value)
    }

    @Test
    fun `deleteProgramme clears name and resets selection state`() = runTest(testDispatcher) {
        viewModel.importProgramme(SAMPLE_JSON, "test_prog")
        advanceUntilIdle()
        viewModel.selectedWeek.value = 1
        viewModel.selectedDay.value = "Day A"
        viewModel.showTable.value = true
        viewModel.showHistory.value = true
        advanceUntilIdle()
        val ex = viewModel.exercises.observeOnce()!!.first()
        viewModel.selectedExercise.value = ex
        advanceUntilIdle()

        viewModel.deleteProgramme()
        advanceUntilIdle()

        assertEquals("", viewModel.programmeName.value)
        assertNull(viewModel.selectedWeek.value)
        assertNull(viewModel.selectedDay.value)
        assertNull(viewModel.selectedExercise.value)
        assertEquals(false, viewModel.showTable.value)
        assertEquals(false, viewModel.showHistory.value)
        assertEquals(false, viewModel.hasProgramme.observeOnce())
    }

    // --- availableProgrammes ---

    @Test
    fun `availableProgrammes lists every imported programme`() = runTest(testDispatcher) {
        // Allow preload of bundled programmes to settle.
        advanceUntilIdle()

        viewModel.importProgramme(SAMPLE_JSON, "first")
        advanceUntilIdle()
        viewModel.importProgramme(SAMPLE_JSON_TWO, "second")
        advanceUntilIdle()

        val names = viewModel.availableProgrammes.observeOnce()!!.map(Programme::name)
        assertTrue("first should be listed: $names", names.contains("first"))
        assertTrue("second should be listed: $names", names.contains("second"))
    }

    // --- importProgrammeFromXlsx ---

    @Test
    fun `importProgrammeFromXlsx - happy path imports exercises and exposes weeks`() =
        runTest(testDispatcher) {
            val stream = javaClass.classLoader!!.getResourceAsStream("programmes/essentials_2x.xlsx")!!
            var result: ImportResult? = null
            viewModel.importProgrammeFromXlsx(stream, "from_xlsx") { result = it }
            advanceUntilIdle()

            assertEquals(ImportResult.IMPORTED, result)
            assertEquals("from_xlsx", viewModel.programmeName.value)
            assertEquals(true, viewModel.hasProgramme.observeOnce())
        }

    @Test
    fun `importProgrammeFromXlsx with broken stream - callback not invoked, no crash`() =
        runTest(testDispatcher) {
            // Empty/garbage stream — XlsxParser will throw, ViewModel swallows it.
            val brokenStream = "not a real xlsx".byteInputStream()
            var invoked = false
            viewModel.importProgrammeFromXlsx(brokenStream, "broken") { invoked = true }
            advanceUntilIdle()

            assertFalse("Failure path should swallow exception, not propagate", invoked)
            assertEquals("", viewModel.programmeName.value)
        }

    // --- exportProgramme ---

    @Test
    fun `exportProgramme - invokes onResult with failure when Firebase init not available`() =
        runTest(testDispatcher) {
            viewModel.importProgramme(SAMPLE_JSON, "test_prog")
            advanceUntilIdle()

            var invoked = false
            var firebaseOk: Boolean? = null
            viewModel.exportProgramme("user-id") { _, ok ->
                invoked = true
                firebaseOk = ok
            }
            advanceUntilIdle()

            // Robolectric has no FirebaseApp initialized — `firebaseSyncManager.exportProgramme`
            // touches `auth.currentUser` lazily and throws. ViewModel catches and surfaces
            // the failure via the callback so the UI can still react.
            assertTrue("callback should fire on the failure path", invoked)
            assertEquals(false, firebaseOk)
        }

    // --- Helpers ---

    private fun installInMemoryDatabase() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val freshDb = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        // Swap the @Volatile companion INSTANCE field via reflection so
        // ProgrammeViewModel sees this DB instead of building its own.
        val instanceField = AppDatabase::class.java.getDeclaredField("INSTANCE")
        instanceField.isAccessible = true
        instanceField.set(null, freshDb)
    }

    private fun clearPrefs() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        ctx.getSharedPreferences("fit_prefs", android.content.Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    private fun <T> LiveData<T>.observeOnce(): T? {
        var result: T? = null
        val observer = Observer<T> { result = it }
        observeForever(observer)
        try {
            return result
        } finally {
            removeObserver(observer)
        }
    }

    companion object {
        private val SAMPLE_JSON = """
            {
              "weeks": [
                {
                  "week": 1,
                  "days": [
                    {
                      "day": "Day A",
                      "exercises": [
                        {"name": "Squat", "sets": 3, "reps": "5", "rpe": "8-9", "order": 0},
                        {"name": "Bench", "sets": 3, "reps": "8", "rpe": "8", "order": 1}
                      ]
                    },
                    {
                      "day": "Day B",
                      "exercises": [
                        {"name": "Deadlift", "sets": 1, "reps": "5", "rpe": "9", "order": 0}
                      ]
                    }
                  ]
                },
                {
                  "week": 2,
                  "days": [
                    {
                      "day": "Day A",
                      "exercises": [
                        {"name": "Squat", "sets": 3, "reps": "5", "rpe": "9", "order": 0}
                      ]
                    }
                  ]
                }
              ]
            }
        """.trimIndent()

        private val SAMPLE_JSON_TWO = """
            {
              "weeks": [
                {
                  "week": 1,
                  "days": [
                    {
                      "day": "Push",
                      "exercises": [
                        {"name": "OHP", "sets": 3, "reps": "5", "rpe": "8", "order": 0}
                      ]
                    }
                  ]
                }
              ]
            }
        """.trimIndent()
    }
}
