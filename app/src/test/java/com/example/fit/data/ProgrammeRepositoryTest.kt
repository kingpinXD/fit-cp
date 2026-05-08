package com.example.fit.data

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.lifecycle.LiveData
import androidx.lifecycle.Observer
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.example.fit.FitApp
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
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
import java.time.Instant

/**
 * Repository-level integration tests against an in-memory Room database.
 * Covers import / switch / delete / log mutation / completion / history / export flows.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = FitApp::class)
class ProgrammeRepositoryTest {

    @get:Rule
    val instantTaskRule = InstantTaskExecutorRule()

    private lateinit var db: AppDatabase
    private lateinit var repo: ProgrammeRepository

    @Before
    fun setUp() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        // Wipe prefs so each test starts with no active programme.
        ctx.getSharedPreferences("fit_prefs", android.content.Context.MODE_PRIVATE)
            .edit().clear().apply()

        db = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        repo = ProgrammeRepository(
            db.exerciseDao(),
            db.exerciseLogDao(),
            db.programmeDao(),
            ctx
        )
    }

    @After
    fun tearDown() {
        db.close()
    }

    // --- Programme name persistence ---

    @Test
    fun `setProgrammeName then getProgrammeName round-trips`() {
        assertEquals("", repo.getProgrammeName())
        repo.setProgrammeName("my_prog")
        assertEquals("my_prog", repo.getProgrammeName())
    }

    // --- Import: JSON ---

    @Test
    fun `importProgrammeFromJson - inserts exercises and registers programme`() = runTest {
        val result = repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        assertEquals(ImportResult.IMPORTED, result)
        assertEquals("test_prog", repo.getProgrammeName())
        assertTrue(repo.programmeExists("test_prog"))
    }

    @Test
    fun `importProgrammeFromJson - second import with same name returns SWITCHED`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        repo.setProgrammeName("")  // simulate user not actively on it

        val second = repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        assertEquals(ImportResult.SWITCHED, second)
        assertEquals("test_prog", repo.getProgrammeName())
    }

    @Test
    fun `importProgrammeFromJson - exercises preserve order, week and day`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val all = db.exerciseDao().getAllExercises("test_prog")

        val w1A = all.filter { it.weekNumber == 1 && it.dayName == "Day A" }
            .sortedBy { it.orderIndex }
        assertEquals(listOf("Squat", "Bench"), w1A.map { it.exerciseName })
        assertEquals("8-9", w1A.first { it.exerciseName == "Squat" }.rpe)
    }

    @Test
    fun `importProgrammeFromJson - distinct programmes coexist`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "first")
        repo.importProgrammeFromJson(SAMPLE_JSON_TWO, "second")

        assertTrue(repo.programmeExists("first"))
        assertTrue(repo.programmeExists("second"))
        assertEquals("second", repo.getProgrammeName())

        val firstCount = db.exerciseDao().countByProgramme("first")
        val secondCount = db.exerciseDao().countByProgramme("second")
        assertTrue(firstCount > 0)
        assertTrue(secondCount > 0)
    }

    // --- Delete ---

    @Test
    fun `deleteProgramme removes exercises, logs and registry entry`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val firstEx = db.exerciseDao().getAllExercises("test_prog").first()
        repo.saveLog(
            ExerciseLog(
                exerciseId = firstEx.id,
                userWeight = "100",
                equipmentType = "Barbell",
                userComments = "ok",
                observedRpe = "8",
                status = "DONE"
            )
        )

        repo.deleteProgramme()

        assertEquals("", repo.getProgrammeName())
        assertFalse(repo.programmeExists("test_prog"))
        assertEquals(0, db.exerciseDao().countByProgramme("test_prog"))
        assertNull(db.exerciseLogDao().getLogSync(firstEx.id))
    }

    @Test
    fun `deleteProgramme with no active programme is a no-op`() = runTest {
        // Should not throw.
        repo.deleteProgramme()
        assertEquals("", repo.getProgrammeName())
    }

    // --- Log save / get ---

    @Test
    fun `saveLog and getLogSync round-trip`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val ex = db.exerciseDao().getAllExercises("test_prog").first()

        repo.saveLog(
            ExerciseLog(
                exerciseId = ex.id,
                userWeight = "100",
                equipmentType = "Barbell",
                userComments = "wk1",
                observedRpe = "9",
                status = "DONE"
            )
        )

        val log = repo.getLogSync(ex.id)
        assertNotNull(log)
        assertEquals("100", log!!.userWeight)
        assertEquals("DONE", log.status)
    }

    @Test
    fun `saveLog twice replaces existing log via REPLACE strategy`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val ex = db.exerciseDao().getAllExercises("test_prog").first()

        repo.saveLog(
            ExerciseLog(exerciseId = ex.id, userWeight = "100", userComments = "", observedRpe = "8", status = "DONE")
        )
        val firstId = repo.getLogSync(ex.id)!!.id
        repo.saveLog(
            ExerciseLog(id = firstId, exerciseId = ex.id, userWeight = "110", userComments = "", observedRpe = "9", status = "DONE")
        )

        val log = repo.getLogSync(ex.id)!!
        assertEquals("110", log.userWeight)
        assertEquals("9", log.observedRpe)
    }

    // --- Reactive queries ---

    @Test
    fun `hasProgrammeByName flips true after import`() = runTest {
        assertEquals(false, repo.hasProgrammeByName("test_prog").observeOnce())
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        assertEquals(true, repo.hasProgrammeByName("test_prog").observeOnce())
    }

    @Test
    fun `getDistinctWeeksByName returns sorted weeks`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        assertEquals(listOf(1, 2), repo.getDistinctWeeksByName("test_prog").observeOnce())
    }

    @Test
    fun `getExercises filters by active programme name`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "first")
        repo.importProgrammeFromJson(SAMPLE_JSON_TWO, "second")
        repo.setProgrammeName("first")

        val w1A = repo.getExercises(1, "Day A").observeOnce()!!
        assertEquals(listOf("Squat", "Bench"), w1A.map { it.exerciseName })

        repo.setProgrammeName("second")
        val push = repo.getExercises(1, "Push").observeOnce()!!
        assertEquals(listOf("OHP"), push.map { it.exerciseName })
    }

    // --- Completion logic ---

    @Test
    fun `getCompletedDays - day appears only when every exercise has a log`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val w1A = db.exerciseDao().getAllExercises("test_prog")
            .filter { it.weekNumber == 1 && it.dayName == "Day A" }

        // No logs yet — empty.
        assertEquals(emptyList<String>(), repo.getCompletedDays(1).observeOnce())

        // Half done — still empty.
        repo.saveLog(ExerciseLog(exerciseId = w1A[0].id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        assertEquals(emptyList<String>(), repo.getCompletedDays(1).observeOnce())

        // All done — appears.
        repo.saveLog(ExerciseLog(exerciseId = w1A[1].id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        assertEquals(listOf("Day A"), repo.getCompletedDays(1).observeOnce())
    }

    @Test
    fun `getCompletedWeeks - week appears only when all days are complete`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val all = db.exerciseDao().getAllExercises("test_prog").filter { it.weekNumber == 1 }

        for (ex in all.filter { it.dayName == "Day A" }) {
            repo.saveLog(ExerciseLog(exerciseId = ex.id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        }
        // Day B not yet complete
        assertEquals(emptyList<Int>(), repo.getCompletedWeeks().observeOnce())

        for (ex in all.filter { it.dayName == "Day B" }) {
            repo.saveLog(ExerciseLog(exerciseId = ex.id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        }
        assertEquals(listOf(1), repo.getCompletedWeeks().observeOnce())
    }

    @Test
    fun `getFirstIncompleteDay returns earliest unfinished day`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")

        // Initially, Week 1 Day A is the first incomplete.
        val first = repo.getFirstIncompleteDay()
        assertNotNull(first)
        assertEquals(1, first!!.weekNumber)
        assertEquals("Day A", first.dayName)

        // Complete Week 1 entirely; next call should return Week 2 Day A.
        val w1 = db.exerciseDao().getAllExercises("test_prog").filter { it.weekNumber == 1 }
        for (ex in w1) {
            repo.saveLog(ExerciseLog(exerciseId = ex.id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        }
        val next = repo.getFirstIncompleteDay()
        assertEquals(2, next!!.weekNumber)
        assertEquals("Day A", next.dayName)
    }

    @Test
    fun `getFirstIncompleteDay returns null when entire programme complete`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        for (ex in db.exerciseDao().getAllExercises("test_prog")) {
            repo.saveLog(ExerciseLog(exerciseId = ex.id, userWeight = "", userComments = "", observedRpe = "", status = "DONE"))
        }
        assertNull(repo.getFirstIncompleteDay())
    }

    // --- History ---

    @Test
    fun `getHistory returns prior-week logs sorted descending`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val w1Squat = db.exerciseDao().getAllExercises("test_prog")
            .first { it.weekNumber == 1 && it.exerciseName == "Squat" }
        repo.saveLog(
            ExerciseLog(exerciseId = w1Squat.id, userWeight = "100", userComments = "", observedRpe = "8", status = "DONE")
        )

        val history = repo.getHistory("Squat", currentWeek = 2).observeOnce()!!
        assertEquals(1, history.size)
        assertEquals(1, history.first().weekNumber)
        assertEquals("100", history.first().userWeight)
    }

    @Test
    fun `getHistory empty when current week is 1`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val w1Squat = db.exerciseDao().getAllExercises("test_prog")
            .first { it.weekNumber == 1 && it.exerciseName == "Squat" }
        repo.saveLog(
            ExerciseLog(exerciseId = w1Squat.id, userWeight = "100", userComments = "", observedRpe = "8", status = "DONE")
        )

        val history = repo.getHistory("Squat", currentWeek = 1).observeOnce()!!
        assertTrue(history.isEmpty())
    }

    // --- Export ---

    @Test
    fun `buildExportJson produces parseable JSON with weeks, days and logs`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val ex = db.exerciseDao().getAllExercises("test_prog").first()
        repo.saveLog(
            ExerciseLog(exerciseId = ex.id, userWeight = "100", equipmentType = "Barbell",
                userComments = "wk1", observedRpe = "8", status = "DONE")
        )

        val json = repo.buildExportJson("test_prog", "user-id")
        val root = JSONObject(json)
        assertEquals("test_prog", root.getString("programmeName"))
        assertEquals("user-id", root.getString("identifier"))

        val weeks = root.getJSONObject("programme").getJSONArray("weeks")
        assertEquals(2, weeks.length())

        val logs = root.getJSONArray("logs")
        assertEquals(1, logs.length())
        assertEquals("100", logs.getJSONObject(0).getString("userWeight"))
        assertEquals("DONE", logs.getJSONObject(0).getString("status"))
    }

    @Test
    fun `buildExportJson with blank programmeName falls back to active prefs name`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        val json = repo.buildExportJson("", "user-id")
        val root = JSONObject(json)
        assertEquals("test_prog", root.getString("programmeName"))
    }

    // --- parseProgramme (static) ---

    @Test
    fun `parseProgramme - missing optional fields default to empty or zero`() {
        val minimal = """
            {
              "weeks": [
                { "week": 1, "days": [
                  { "day": "Day A", "exercises": [
                    {"name": "X", "sets": 1, "reps": "5"}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        val out = ProgrammeRepository.parseProgramme(minimal)
        assertEquals(1, out.size)
        val ex = out.first()
        assertEquals("X", ex.exerciseName)
        assertEquals(1, ex.sets)
        assertEquals("5", ex.reps)
        assertEquals("", ex.rpe)
        assertEquals("", ex.notes)
        assertEquals("0", ex.warmupSets)
        assertEquals("", ex.sub1)
        assertEquals("", ex.videoUrl)
    }

    @Test
    fun `parseProgramme - default order falls back to running index when omitted`() {
        val noOrder = """
            {
              "weeks": [
                { "week": 1, "days": [
                  { "day": "Day A", "exercises": [
                    {"name": "A", "sets": 1, "reps": "5"},
                    {"name": "B", "sets": 1, "reps": "5"}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        val out = ProgrammeRepository.parseProgramme(noOrder)
        assertEquals(listOf(0, 1), out.map { it.orderIndex })
    }

    // --- BUNDLED_PROGRAMMES sanity ---

    @Test
    fun `BUNDLED_PROGRAMMES has stable normalized names`() {
        val names = ProgrammeRepository.BUNDLED_PROGRAMMES.map { it.first }
        assertTrue(names.contains("essentials_2x"))
        assertTrue(names.contains("essentials_3x"))
        assertTrue(names.contains("essentials_4x"))
        assertTrue(names.contains("essentials_5x"))
    }

    // --- getAvailableProgrammes ---

    @Test
    fun `getAvailableProgrammes lists imported programmes`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "first")
        repo.importProgrammeFromJson(SAMPLE_JSON_TWO, "second")

        val names = repo.getAvailableProgrammes().observeOnce()!!.map { it.name }
        assertTrue(names.contains("first"))
        assertTrue(names.contains("second"))
    }

    // --- Active-programme delegate accessors ---

    @Test
    fun `hasProgramme - reflects active programme set via prefs`() = runTest {
        // Initially no programme — false.
        assertEquals(false, repo.hasProgramme().observeOnce())

        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        // setProgrammeName already called by import — verify true.
        assertEquals(true, repo.hasProgramme().observeOnce())
    }

    @Test
    fun `getDistinctWeeks - returns weeks for active programme`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        repo.setProgrammeName("test_prog")
        assertEquals(listOf(1, 2), repo.getDistinctWeeks().observeOnce())
    }

    @Test
    fun `getCompletedWeeks - empty for fresh programme, populated after marking week done`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        repo.setProgrammeName("test_prog")
        assertEquals(emptyList<Int>(), repo.getCompletedWeeks().observeOnce())

        for (ex in db.exerciseDao().getAllExercises("test_prog").filter { it.weekNumber == 1 }) {
            repo.saveLog(ExerciseLog(exerciseId = ex.id, userWeight = "", userComments = "",
                observedRpe = "", status = "DONE"))
        }
        assertEquals(listOf(1), repo.getCompletedWeeks().observeOnce())
    }

    @Test
    fun `getLogsForDay - returns logs for active programme's week and day`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "test_prog")
        repo.setProgrammeName("test_prog")
        val all = db.exerciseDao().getAllExercises("test_prog")
        val w1A = all.first { it.weekNumber == 1 && it.dayName == "Day A" }
        repo.saveLog(ExerciseLog(exerciseId = w1A.id, userWeight = "100", userComments = "",
            observedRpe = "8", status = "DONE"))

        val logs = repo.getLogsForDay(1, "Day A").observeOnce()!!
        assertEquals(1, logs.size)
        assertEquals("100", logs.first().userWeight)
    }

    // --- Export JSON shape ---

    @Test
    fun `buildExportJson - full shape with weeks, days, exercises, logs`() = runTest {
        // 2 weeks x 2 days x 2 exercises = 8 exercises, plus 2 logs
        val json = """
            {
              "weeks": [
                {"week": 1, "days": [
                  {"day": "Day A", "exercises": [
                    {"name": "Squat", "sets": 3, "reps": "5", "rpe": "8", "rest": "120s",
                     "warmupSets": "2", "notes": "n1", "order": 0,
                     "sub1": "Goblet Squat", "sub2": "Leg Press"},
                    {"name": "Bench", "sets": 3, "reps": "8", "rpe": "9", "rest": "90s",
                     "warmupSets": "1", "notes": "n2", "order": 1,
                     "sub1": "DB Press", "sub2": ""}
                  ]},
                  {"day": "Day B", "exercises": [
                    {"name": "Row", "sets": 3, "reps": "10", "rpe": "8", "rest": "60s",
                     "warmupSets": "1", "notes": "", "order": 0, "sub1": "", "sub2": ""},
                    {"name": "Curl", "sets": 3, "reps": "12", "rpe": "9", "rest": "45s",
                     "warmupSets": "0", "notes": "", "order": 1, "sub1": "", "sub2": ""}
                  ]}
                ]},
                {"week": 2, "days": [
                  {"day": "Day A", "exercises": [
                    {"name": "Squat", "sets": 4, "reps": "5", "rpe": "9", "rest": "120s",
                     "warmupSets": "2", "notes": "", "order": 0, "sub1": "", "sub2": ""},
                    {"name": "Bench", "sets": 4, "reps": "6", "rpe": "9", "rest": "90s",
                     "warmupSets": "1", "notes": "", "order": 1, "sub1": "", "sub2": ""}
                  ]},
                  {"day": "Day B", "exercises": [
                    {"name": "Row", "sets": 3, "reps": "10", "rpe": "8", "rest": "60s",
                     "warmupSets": "1", "notes": "", "order": 0, "sub1": "", "sub2": ""},
                    {"name": "Curl", "sets": 3, "reps": "12", "rpe": "9", "rest": "45s",
                     "warmupSets": "0", "notes": "", "order": 1, "sub1": "", "sub2": ""}
                  ]}
                ]}
              ]
            }
        """.trimIndent()

        repo.importProgrammeFromJson(json, "test_prog")
        val all = db.exerciseDao().getAllExercises("test_prog")
        repo.saveLog(ExerciseLog(exerciseId = all[0].id, userWeight = "100", equipmentType = "Barbell",
            userComments = "first", observedRpe = "8", status = "DONE"))
        repo.saveLog(ExerciseLog(exerciseId = all[1].id, userWeight = "60", equipmentType = "DB",
            userComments = "second", observedRpe = "9", status = "DONE"))

        val out = repo.buildExportJson("test_prog", "user@x")
        val root = JSONObject(out)

        // Top-level fields
        assertEquals("test_prog", root.getString("programmeName"))
        assertEquals("user@x", root.getString("identifier"))
        // exportDate should be ISO-8601 parseable
        Instant.parse(root.getString("exportDate"))

        // programme.weeks[].days[].exercises[]
        val weeks = root.getJSONObject("programme").getJSONArray("weeks")
        assertEquals(2, weeks.length())
        for (w in 0 until weeks.length()) {
            val weekObj = weeks.getJSONObject(w)
            assertTrue(weekObj.has("week"))
            val days = weekObj.getJSONArray("days")
            assertEquals(2, days.length())
            for (d in 0 until days.length()) {
                val dayObj = days.getJSONObject(d)
                assertTrue(dayObj.has("day"))
                val exs = dayObj.getJSONArray("exercises")
                assertEquals(2, exs.length())
                for (e in 0 until exs.length()) {
                    val ex = exs.getJSONObject(e)
                    val expectedFields = listOf(
                        "name", "sets", "reps", "rpe", "rest",
                        "warmupSets", "notes", "order", "sub1", "sub2"
                    )
                    for (key in expectedFields) {
                        assertTrue("exercise should have $key", ex.has(key))
                    }
                }
            }
        }

        // logs[]
        val logs = root.getJSONArray("logs")
        assertEquals(2, logs.length())
        val expectedLogFields = listOf(
            "exerciseName", "weekNumber", "dayName", "userWeight",
            "equipmentType", "observedRpe", "userComments", "status"
        )
        for (i in 0 until logs.length()) {
            val log = logs.getJSONObject(i)
            for (key in expectedLogFields) {
                assertTrue("log should have $key", log.has(key))
            }
        }
    }

    @Test
    fun `buildExportJson - blank programmeName falls back to active programme prefs`() = runTest {
        repo.importProgrammeFromJson(SAMPLE_JSON, "active_prog")
        repo.setProgrammeName("active_prog")

        val out = repo.buildExportJson("", "id")
        val root = JSONObject(out)
        assertEquals("active_prog", root.getString("programmeName"))
    }

    // --- preloadProgrammes ---

    @Test
    fun `preloadProgrammes - second call is idempotent`() = runTest {
        repo.preloadProgrammes()
        val counts1 = ProgrammeRepository.BUNDLED_PROGRAMMES.associate { (n, _) ->
            n to db.exerciseDao().countByProgramme(n)
        }
        // sanity: each bundled programme has exercises
        for ((_, c) in counts1) assertTrue("Each bundled programme has exercises", c > 0)

        repo.preloadProgrammes()
        val counts2 = ProgrammeRepository.BUNDLED_PROGRAMMES.associate { (n, _) ->
            n to db.exerciseDao().countByProgramme(n)
        }

        assertEquals(counts1, counts2)
    }

    @Test
    fun `deduplicateExercises - 2x trims excess exercises down to 180`() = runTest {
        seedDuplicateExercises("essentials_2x", count = 200)
        repo.preloadProgrammes()
        assertEquals(180, db.exerciseDao().countByProgramme("essentials_2x"))
    }

    @Test
    fun `deduplicateExercises - 3x trims excess exercises down to 240`() = runTest {
        seedDuplicateExercises("essentials_3x", count = 260)
        repo.preloadProgrammes()
        assertEquals(240, db.exerciseDao().countByProgramme("essentials_3x"))
    }

    @Test
    fun `deduplicateExercises - 4x trims excess exercises down to 288`() = runTest {
        // 4x duplicates also trigger repair4xDayNames since seeded names lack the #2 suffix.
        // After repair the programme is re-preloaded from assets to the canonical 288.
        seedDuplicateExercises("essentials_4x", count = 300)
        repo.preloadProgrammes()
        assertEquals(288, db.exerciseDao().countByProgramme("essentials_4x"))
    }

    @Test
    fun `deduplicateExercises - 5x trims excess exercises down to 324`() = runTest {
        seedDuplicateExercises("essentials_5x", count = 350)
        repo.preloadProgrammes()
        assertEquals(324, db.exerciseDao().countByProgramme("essentials_5x"))
    }

    @Test
    fun `repair4xDayNames - rewrites programme when week 1 has fewer than 4 day names`() = runTest {
        // Insert 4x exercises with only 2 distinct day names in week 1 (mimics legacy bug).
        val bad = (1..20).flatMap { weekIdx ->
            listOf("Upper", "Lower").flatMap { day ->
                (1..5).map { ord ->
                    Exercise(
                        weekNumber = weekIdx,
                        dayName = day,
                        exerciseName = "ex_$ord",
                        sets = 3,
                        reps = "5",
                        orderIndex = ord,
                        programmeName = "essentials_4x"
                    )
                }
            }
        }
        db.exerciseDao().insertAll(bad)
        db.programmeDao().upsert(Programme(name = "essentials_4x", importedAt = Instant.now().toString()))
        // Sanity: only 2 distinct day names in week 1 before repair
        val before = db.exerciseDao().getAllExercises("essentials_4x")
            .filter { it.weekNumber == 1 }.map { it.dayName }.distinct()
        assertEquals(2, before.size)

        repo.preloadProgrammes()

        // After repair: programme should have 4 distinct day names per week (from bundled asset)
        val after = db.exerciseDao().getAllExercises("essentials_4x")
            .filter { it.weekNumber == 1 }.map { it.dayName }.distinct()
        assertEquals(4, after.size)
        assertTrue(after.contains("Upper #2"))
    }

    // --- cleanupLegacyNames ---

    @Test
    fun `cleanupLegacyNames - underscore legacy 'the_essentials_2x' renamed to 'essentials_2x'`() = runTest {
        // Pre-insert under the legacy underscore-prefixed name.
        val legacy = "the_essentials_2x"
        val newName = "essentials_2x"
        seedDuplicateExercises(legacy, count = 5)
        db.programmeDao().upsert(Programme(name = legacy, importedAt = Instant.now().toString()))
        repo.setProgrammeName(legacy)

        repo.preloadProgrammes()

        // Old programme registry entry gone, exercises moved across to new name.
        assertFalse(db.programmeDao().exists(legacy))
        assertTrue(db.programmeDao().exists(newName))
        assertEquals(0, db.exerciseDao().countByProgramme(legacy))
        // The 5 original rows are now under the new name (preload skips since it now exists).
        assertEquals(5, db.exerciseDao().countByProgramme(newName))
        // Active programme name is updated.
        assertEquals(newName, repo.getProgrammeName())
    }

    @Test
    fun `cleanupLegacyNames - space-cased legacy 'Essentials 5x' renamed to 'essentials_5x'`() = runTest {
        val legacy = "Essentials 5x"
        val newName = "essentials_5x"
        seedDuplicateExercises(legacy, count = 5)
        db.programmeDao().upsert(Programme(name = legacy, importedAt = Instant.now().toString()))
        repo.setProgrammeName(legacy)

        repo.preloadProgrammes()

        assertFalse(db.programmeDao().exists(legacy))
        assertTrue(db.programmeDao().exists(newName))
        assertEquals(0, db.exerciseDao().countByProgramme(legacy))
        assertEquals(newName, repo.getProgrammeName())
    }

    @Test
    fun `cleanupLegacyNames - prefs untouched when active programme differs`() = runTest {
        seedDuplicateExercises("the_essentials_3x", count = 5)
        db.programmeDao().upsert(Programme(name = "the_essentials_3x", importedAt = Instant.now().toString()))
        repo.setProgrammeName("something_else")

        repo.preloadProgrammes()

        assertEquals("something_else", repo.getProgrammeName())
    }

    // --- parseProgramme edge cases ---

    @Test
    fun `parseProgramme - empty exercises array yields no exercises for that day`() {
        val empty = """
            {
              "weeks": [
                {"week": 1, "days": [
                  {"day": "Day A", "exercises": []},
                  {"day": "Day B", "exercises": [
                    {"name": "X", "sets": 1, "reps": "5"}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        val out = ProgrammeRepository.parseProgramme(empty)
        assertEquals(1, out.size)
        assertEquals("Day B", out.first().dayName)
    }

    @Test
    fun `parseProgramme - multiple exercises without 'order' get insertion-index orderIndex`() {
        val noOrder = """
            {
              "weeks": [
                {"week": 1, "days": [
                  {"day": "Day A", "exercises": [
                    {"name": "A", "sets": 1, "reps": "5"},
                    {"name": "B", "sets": 1, "reps": "5"},
                    {"name": "C", "sets": 1, "reps": "5"}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        val out = ProgrammeRepository.parseProgramme(noOrder)
        assertEquals(listOf(0, 1, 2), out.map { it.orderIndex })
    }

    @Test
    fun `parseProgramme - all optional fields default correctly`() {
        val minimal = """
            {
              "weeks": [
                {"week": 1, "days": [
                  {"day": "Day A", "exercises": [
                    {"name": "X", "sets": 1, "reps": "5"}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        val ex = ProgrammeRepository.parseProgramme(minimal).first()
        assertEquals("", ex.rpe)
        assertEquals("", ex.rest)
        assertEquals("", ex.notes)
        assertEquals("0", ex.warmupSets)
        assertEquals("", ex.sub1)
        assertEquals("", ex.sub2)
        assertEquals("", ex.videoUrl)
        assertEquals("", ex.sub1VideoUrl)
        assertEquals("", ex.sub2VideoUrl)
    }

    // --- importProgrammeFromJson failure ---

    @Test(expected = org.json.JSONException::class)
    fun `importProgrammeFromJson - malformed JSON throws and inserts nothing`() = runTest {
        val before = db.exerciseDao().count()
        try {
            repo.importProgrammeFromJson("{not valid json", "broken")
        } finally {
            // Confirm nothing was inserted before the throw.
            assertEquals(before, db.exerciseDao().count())
        }
    }

    // --- importProgrammeFromXlsx ---

    @Test
    fun `importProgrammeFromXlsx - happy path inserts exercises under given name`() = runTest {
        val stream = javaClass.classLoader!!.getResourceAsStream("programmes/essentials_2x.xlsx")!!
        val result = repo.importProgrammeFromXlsx(stream, "from_xlsx")

        assertEquals(ImportResult.IMPORTED, result)
        assertEquals("from_xlsx", repo.getProgrammeName())
        assertTrue(db.exerciseDao().countByProgramme("from_xlsx") > 0)
        // 2x has Full Body A / Full Body B in week 1.
        val w1Days = db.exerciseDao().getAllExercises("from_xlsx")
            .filter { it.weekNumber == 1 }.map { it.dayName }.distinct()
        assertTrue(w1Days.contains("Full Body A"))
        assertTrue(w1Days.contains("Full Body B"))
    }

    @Test
    fun `importProgrammeFromXlsx - re-import with same name returns SWITCHED`() = runTest {
        val stream1 = javaClass.classLoader!!.getResourceAsStream("programmes/essentials_2x.xlsx")!!
        repo.importProgrammeFromXlsx(stream1, "from_xlsx")
        repo.setProgrammeName("")

        val stream2 = javaClass.classLoader!!.getResourceAsStream("programmes/essentials_2x.xlsx")!!
        val second = repo.importProgrammeFromXlsx(stream2, "from_xlsx")
        assertEquals(ImportResult.SWITCHED, second)
        assertEquals("from_xlsx", repo.getProgrammeName())
    }

    // --- getFirstIncompleteDay - sparse gaps ---

    @Test
    fun `getFirstIncompleteDay - skips fully logged day and returns next exercise-only day`() = runTest {
        // Build a programme with W1D1 (logged), W1D3 (no logs), W2D1 (no logs) — note no W1D2.
        val json = """
            {
              "weeks": [
                {"week": 1, "days": [
                  {"day": "W1D1", "exercises": [
                    {"name": "A1", "sets": 1, "reps": "5", "order": 0}
                  ]},
                  {"day": "W1D3", "exercises": [
                    {"name": "C1", "sets": 1, "reps": "5", "order": 0}
                  ]}
                ]},
                {"week": 2, "days": [
                  {"day": "W2D1", "exercises": [
                    {"name": "X1", "sets": 1, "reps": "5", "order": 0}
                  ]}
                ]}
              ]
            }
        """.trimIndent()
        repo.importProgrammeFromJson(json, "sparse")
        val all = db.exerciseDao().getAllExercises("sparse")
        // Log W1D1 fully so it is complete.
        val w1d1 = all.first { it.weekNumber == 1 && it.dayName == "W1D1" }
        repo.saveLog(ExerciseLog(exerciseId = w1d1.id, userWeight = "", userComments = "",
            observedRpe = "", status = "DONE"))

        val firstIncomplete = repo.getFirstIncompleteDay()
        assertNotNull(firstIncomplete)
        assertEquals(1, firstIncomplete!!.weekNumber)
        assertEquals("W1D3", firstIncomplete.dayName)
    }

    // --- Helpers ---

    /**
     * Insert [count] minimal Exercise rows under [programmeName] without going through
     * the parsed JSON path. Used to seed fixtures that mimic legacy/duplicated state.
     */
    private suspend fun seedDuplicateExercises(programmeName: String, count: Int) {
        val rows = (1..count).map { i ->
            Exercise(
                weekNumber = 1,
                dayName = "D",
                exerciseName = "ex_$i",
                sets = 1,
                reps = "5",
                orderIndex = i,
                programmeName = programmeName
            )
        }
        db.exerciseDao().insertAll(rows)
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
                        {"name": "Squat", "sets": 3, "reps": "5", "rpe": "9", "order": 0},
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
