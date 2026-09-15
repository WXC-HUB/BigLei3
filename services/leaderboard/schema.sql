CREATE TABLE IF NOT EXISTS scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id TEXT NOT NULL,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(stage_id, name)
);

CREATE INDEX IF NOT EXISTS idx_scores_stage_score ON scores(stage_id, score DESC);

-- 每日排行（多游戏共用，game_id 区分；day 为北京时间 YYYY-MM-DD，每天 00:00 自动换榜）
CREATE TABLE IF NOT EXISTS daily_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id TEXT NOT NULL,
  day TEXT NOT NULL,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  avatar TEXT,
  score INTEGER NOT NULL,
  runs INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  UNIQUE(game_id, day, user_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_scores_board ON daily_scores(game_id, day, score DESC, updated_at ASC);
CREATE INDEX IF NOT EXISTS idx_daily_scores_day ON daily_scores(day);
