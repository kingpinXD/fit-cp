package com.example.fit.data

import android.content.Context
import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase

@Entity(tableName = "exercises")
data class Exercise(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val weekNumber: Int,
    val dayName: String,
    val exerciseName: String,
    val sets: Int,
    val reps: String,
    val orderIndex: Int,
    val rpe: String = "",
    val notes: String = "",
    val warmupSets: String = "0",
    val rest: String = "",
    val sub1: String = "",
    val sub2: String = "",
    val videoUrl: String = "",
    val sub1VideoUrl: String = "",
    val sub2VideoUrl: String = "",
    val programmeName: String = ""
)

@Entity(tableName = "exercise_logs")
data class ExerciseLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val exerciseId: Long,
    val userWeight: String,
    val equipmentType: String = "", // comma-separated: "Barbell,Each Side"
    val userComments: String,
    val observedRpe: String,
    val status: String // "PENDING", "DONE", "SKIPPED"
)

data class DayInfo(val weekNumber: Int, val dayName: String)

@Dao
interface ExerciseDao {
    @Query("SELECT * FROM exercises WHERE programmeName = :programmeName AND weekNumber = :weekNumber AND dayName = :dayName ORDER BY orderIndex")
    fun getExercises(programmeName: String, weekNumber: Int, dayName: String): LiveData<List<Exercise>>

    @Query("SELECT DISTINCT weekNumber FROM exercises WHERE programmeName = :programmeName ORDER BY weekNumber")
    fun getDistinctWeeks(programmeName: String): LiveData<List<Int>>

    @Query("SELECT dayName FROM exercises WHERE programmeName = :programmeName AND weekNumber = :weekNumber GROUP BY dayName ORDER BY MIN(id)")
    fun getDistinctDays(programmeName: String, weekNumber: Int): LiveData<List<String>>

    @Insert
    suspend fun insertAll(exercises: List<Exercise>)

    @Query("SELECT COUNT(*) FROM exercises")
    suspend fun count(): Int

    @Query("SELECT COUNT(*) FROM exercises WHERE programmeName = :programmeName")
    fun countLive(programmeName: String): LiveData<Int>

    @Query("SELECT COUNT(*) FROM exercises WHERE programmeName = :programmeName")
    suspend fun countByProgramme(programmeName: String): Int

    @Query("SELECT * FROM exercises WHERE programmeName = :programmeName ORDER BY weekNumber, id")
    suspend fun getAllExercises(programmeName: String): List<Exercise>

    // Returns day names that are fully complete (all exercises have a log)
    @Query(
        "SELECT e.dayName FROM exercises e " +
        "WHERE e.programmeName = :programmeName AND e.weekNumber = :weekNumber " +
        "GROUP BY e.dayName " +
        "HAVING COUNT(e.id) = (" +
        "  SELECT COUNT(el.id) FROM exercise_logs el " +
        "  INNER JOIN exercises e2 ON el.exerciseId = e2.id " +
        "  WHERE e2.programmeName = :programmeName AND e2.weekNumber = :weekNumber AND e2.dayName = e.dayName" +
        ") " +
        "ORDER BY MIN(e.id)"
    )
    fun getCompletedDays(programmeName: String, weekNumber: Int): LiveData<List<String>>

    // Returns week numbers where ALL days are complete
    @Query(
        "SELECT e.weekNumber FROM exercises e " +
        "WHERE e.programmeName = :programmeName " +
        "GROUP BY e.weekNumber " +
        "HAVING COUNT(e.id) = (" +
        "  SELECT COUNT(el.id) FROM exercise_logs el " +
        "  INNER JOIN exercises e2 ON el.exerciseId = e2.id " +
        "  WHERE e2.programmeName = :programmeName AND e2.weekNumber = e.weekNumber" +
        ") " +
        "ORDER BY e.weekNumber"
    )
    fun getCompletedWeeks(programmeName: String): LiveData<List<Int>>

    @Query(
        "SELECT e.weekNumber, e.dayName FROM exercises e " +
        "WHERE e.programmeName = :programmeName " +
        "GROUP BY e.weekNumber, e.dayName " +
        "HAVING COUNT(e.id) > (" +
        "  SELECT COUNT(el.id) FROM exercise_logs el " +
        "  INNER JOIN exercises e2 ON el.exerciseId = e2.id " +
        "  WHERE e2.programmeName = :programmeName AND e2.weekNumber = e.weekNumber AND e2.dayName = e.dayName" +
        ") " +
        "ORDER BY e.weekNumber, MIN(e.id) " +
        "LIMIT 1"
    )
    suspend fun getFirstIncompleteDay(programmeName: String): DayInfo?

    @Query("DELETE FROM exercises")
    suspend fun deleteAll()

    @Query("DELETE FROM exercises WHERE programmeName = :programmeName")
    suspend fun deleteByProgramme(programmeName: String)

    @Query("UPDATE exercises SET programmeName = :newName WHERE programmeName = :oldName")
    suspend fun renameProgramme(oldName: String, newName: String)

    @Query("DELETE FROM exercises WHERE programmeName = :programmeName AND id NOT IN (SELECT id FROM exercises WHERE programmeName = :programmeName ORDER BY id LIMIT :keepCount)")
    suspend fun deduplicateByProgramme(programmeName: String, keepCount: Int)
}

data class ExerciseHistoryEntry(
    val weekNumber: Int,
    val userWeight: String,
    val equipmentType: String,
    val userComments: String,
    val observedRpe: String,
    val status: String
)

data class ExportLogEntry(
    val exerciseName: String,
    val weekNumber: Int,
    val dayName: String,
    val userWeight: String,
    val equipmentType: String,
    val userComments: String,
    val observedRpe: String,
    val status: String
)

@Dao
interface ExerciseLogDao {
    @Query("SELECT * FROM exercise_logs WHERE exerciseId = :exerciseId LIMIT 1")
    fun getLog(exerciseId: Long): LiveData<ExerciseLog?>

    @Query("SELECT * FROM exercise_logs WHERE exerciseId = :exerciseId LIMIT 1")
    suspend fun getLogSync(exerciseId: Long): ExerciseLog?

    @Query(
        "SELECT el.* FROM exercise_logs el " +
        "INNER JOIN exercises e ON el.exerciseId = e.id " +
        "WHERE e.programmeName = :programmeName AND e.weekNumber = :weekNumber AND e.dayName = :dayName"
    )
    fun getLogsForDay(programmeName: String, weekNumber: Int, dayName: String): LiveData<List<ExerciseLog>>

    @Query(
        "SELECT e.weekNumber, el.userWeight, el.equipmentType, el.userComments, el.observedRpe, el.status " +
        "FROM exercise_logs el " +
        "INNER JOIN exercises e ON el.exerciseId = e.id " +
        "WHERE e.programmeName = :programmeName AND e.exerciseName = :exerciseName AND e.weekNumber < :currentWeek " +
        "ORDER BY e.weekNumber DESC"
    )
    fun getHistory(programmeName: String, exerciseName: String, currentWeek: Int): LiveData<List<ExerciseHistoryEntry>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(log: ExerciseLog)

    @Query(
        "SELECT e.exerciseName, e.weekNumber, e.dayName, " +
        "el.userWeight, el.equipmentType, el.userComments, el.observedRpe, el.status " +
        "FROM exercise_logs el " +
        "INNER JOIN exercises e ON el.exerciseId = e.id " +
        "WHERE e.programmeName = :programmeName " +
        "ORDER BY e.weekNumber, e.id"
    )
    suspend fun getExportLogs(programmeName: String): List<ExportLogEntry>

    @Query("DELETE FROM exercise_logs")
    suspend fun deleteAll()

    @Query("DELETE FROM exercise_logs WHERE exerciseId IN (SELECT id FROM exercises WHERE programmeName = :programmeName)")
    suspend fun deleteByProgramme(programmeName: String)
}

@Entity(tableName = "programmes")
data class Programme(
    @PrimaryKey val name: String,
    val importedAt: String // ISO 8601
)

@Dao
interface ProgrammeDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(programme: Programme)

    @Query("SELECT * FROM programmes ORDER BY importedAt DESC")
    fun getAll(): LiveData<List<Programme>>

    @Query("SELECT COUNT(*) FROM programmes WHERE name = :name")
    suspend fun exists(name: String): Boolean

    @Query("DELETE FROM programmes WHERE name = :name")
    suspend fun delete(name: String)
}

@Database(entities = [Exercise::class, ExerciseLog::class, Programme::class], version = 9, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {

    abstract fun exerciseDao(): ExerciseDao
    abstract fun exerciseLogDao(): ExerciseLogDao
    abstract fun programmeDao(): ProgrammeDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        internal val MIGRATION_8_9 = object : androidx.room.migration.Migration(8, 9) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE exercises ADD COLUMN rest TEXT NOT NULL DEFAULT ''")
            }
        }

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "fit.db"
                )
                    .addMigrations(MIGRATION_8_9)
                    .fallbackToDestructiveMigration()
                    .build().also { INSTANCE = it }
            }
        }
    }
}
