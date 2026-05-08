package com.example.fit.data

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.example.fit.FitApp
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Verifies the v8 -> v9 Room migration adds the `rest` column to `exercises`
 * with an empty-string default and preserves existing rows.
 *
 * The schema is built by hand because the database is configured with
 * `exportSchema = false`, so [androidx.room.testing.MigrationTestHelper] is not
 * available. Instead we open a raw SQLite DB at v8, seed it, then re-open via
 * Room with the migration registered.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = FitApp::class)
class MigrationTest {

    private val dbName = "migration_test.db"
    private lateinit var ctx: Context

    @Before
    fun setUp() {
        ctx = ApplicationProvider.getApplicationContext()
        ctx.deleteDatabase(dbName)
    }

    @After
    fun tearDown() {
        ctx.deleteDatabase(dbName)
    }

    @Test
    fun `MIGRATION_8_9 adds rest column with empty default and preserves rows`() = runTest {
        // 1. Build a v8-shaped DB by hand: same as v9 minus the `rest` column on `exercises`.
        val factory = FrameworkSQLiteOpenHelperFactory()
        val v8Helper = factory.create(
            androidx.sqlite.db.SupportSQLiteOpenHelper.Configuration.builder(ctx)
                .name(dbName)
                .callback(object : androidx.sqlite.db.SupportSQLiteOpenHelper.Callback(8) {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `exercises` (" +
                                "`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                                "`weekNumber` INTEGER NOT NULL, " +
                                "`dayName` TEXT NOT NULL, " +
                                "`exerciseName` TEXT NOT NULL, " +
                                "`sets` INTEGER NOT NULL, " +
                                "`reps` TEXT NOT NULL, " +
                                "`orderIndex` INTEGER NOT NULL, " +
                                "`rpe` TEXT NOT NULL, " +
                                "`notes` TEXT NOT NULL, " +
                                "`warmupSets` TEXT NOT NULL, " +
                                "`sub1` TEXT NOT NULL, " +
                                "`sub2` TEXT NOT NULL, " +
                                "`videoUrl` TEXT NOT NULL, " +
                                "`sub1VideoUrl` TEXT NOT NULL, " +
                                "`sub2VideoUrl` TEXT NOT NULL, " +
                                "`programmeName` TEXT NOT NULL)"
                        )
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `exercise_logs` (" +
                                "`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                                "`exerciseId` INTEGER NOT NULL, " +
                                "`userWeight` TEXT NOT NULL, " +
                                "`equipmentType` TEXT NOT NULL, " +
                                "`userComments` TEXT NOT NULL, " +
                                "`observedRpe` TEXT NOT NULL, " +
                                "`status` TEXT NOT NULL)"
                        )
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `programmes` (" +
                                "`name` TEXT NOT NULL, " +
                                "`importedAt` TEXT NOT NULL, " +
                                "PRIMARY KEY(`name`))"
                        )
                        // Room expects this metadata table to exist on every Room DB.
                        db.execSQL("CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)")
                    }

                    override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {
                        // No-op: v8 is the starting point.
                    }
                })
                .build()
        )

        v8Helper.writableDatabase.use { db ->
            db.execSQL(
                "INSERT INTO exercises " +
                    "(weekNumber, dayName, exerciseName, sets, reps, orderIndex, rpe, notes, warmupSets, " +
                    "sub1, sub2, videoUrl, sub1VideoUrl, sub2VideoUrl, programmeName) " +
                    "VALUES (1, 'Day A', 'Squat', 3, '5', 0, '8', '', '0', '', '', '', '', '', 'old_prog')"
            )
        }

        // 2. Re-open through Room with the migration registered. Room runs MIGRATION_8_9
        //    automatically because the on-disk schema is at version 8.
        val db = Room.databaseBuilder(ctx, AppDatabase::class.java, dbName)
            .addMigrations(AppDatabase.MIGRATION_8_9)
            .allowMainThreadQueries()
            .build()

        try {
            val rows = db.exerciseDao().getAllExercises("old_prog")
            assertEquals(1, rows.size)
            val ex = rows.first()
            assertEquals("Squat", ex.exerciseName)
            assertEquals(1, ex.weekNumber)
            assertEquals("Day A", ex.dayName)
            assertEquals(3, ex.sets)
            assertEquals("5", ex.reps)
            assertEquals(0, ex.orderIndex)
            assertEquals("8", ex.rpe)
            assertEquals("", ex.notes)
            assertEquals("0", ex.warmupSets)
            // The new column gets the empty-string default from MIGRATION_8_9.
            assertEquals("", ex.rest)
            assertEquals("old_prog", ex.programmeName)
        } finally {
            db.close()
        }
    }
}
