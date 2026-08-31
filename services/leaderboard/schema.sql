CREATE TABLE IF NOT EXISTS scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id TEXT NOT NULL,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(stage_id, name)
);

CREATE INDEX IF NOT EXISTS idx_scores_stage_score ON scores(stage_id, score DESC);
