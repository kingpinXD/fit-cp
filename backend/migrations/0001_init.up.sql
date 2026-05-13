CREATE TABLE exercises (
  id           text PRIMARY KEY,           -- slug like "Barbell_Curl"
  name         text NOT NULL,
  force        text,                       -- push|pull|static|null
  level        text NOT NULL,              -- beginner|intermediate|expert
  mechanic     text,                       -- compound|isolation|null
  equipment    text,                       -- barbell|dumbbell|... |null
  category     text NOT NULL,              -- strength|cardio|...
  instructions text[] NOT NULL DEFAULT '{}',
  image_urls   text[] NOT NULL DEFAULT '{}',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE exercise_muscles (
  exercise_id text NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  muscle      text NOT NULL,
  role        text NOT NULL CHECK (role IN ('primary','secondary')),
  PRIMARY KEY (exercise_id, muscle, role)
);

CREATE INDEX idx_exercises_level         ON exercises(level);
CREATE INDEX idx_exercises_equipment     ON exercises(equipment);
CREATE INDEX idx_exercises_category      ON exercises(category);
CREATE INDEX idx_exercise_muscles_muscle ON exercise_muscles(muscle);
