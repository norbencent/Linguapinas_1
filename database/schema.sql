-- LinguaPinas SQLite schema.
-- Executed by scripts/autoload/db.gd the first time the game starts.
-- Each statement must end with a semicolon at the end of a line.

CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Player accounts (stored locally: the game is fully offline).
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    display_name  TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    salt          TEXT NOT NULL,
    created_at    TEXT NOT NULL DEFAULT (datetime('now')),
    last_login    TEXT
);

-- Island groups. Each one has a Language Core to restore.
CREATE TABLE IF NOT EXISTS regions (
    code        TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    core_name   TEXT NOT NULL,
    description TEXT NOT NULL,
    color       TEXT NOT NULL,
    sort_order  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS languages (
    code        TEXT PRIMARY KEY,
    region_code TEXT NOT NULL REFERENCES regions(code),
    name        TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    playable    INTEGER NOT NULL DEFAULT 0,
    sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS categories (
    code       TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

-- Vocabulary used by lessons and Easy quizzes.
CREATE TABLE IF NOT EXISTS words (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    language_code TEXT NOT NULL REFERENCES languages(code),
    category_code TEXT NOT NULL REFERENCES categories(code),
    native        TEXT NOT NULL,
    english       TEXT NOT NULL,
    note          TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_words_language ON words(language_code);

-- Sentences and dialogues used by lessons, Medium and Hard quizzes.
-- context: an English situation used by "what would you say?" questions.
CREATE TABLE IF NOT EXISTS sentences (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    language_code TEXT NOT NULL REFERENCES languages(code),
    native        TEXT NOT NULL,
    english       TEXT NOT NULL,
    context       TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_sentences_language ON sentences(language_code);

-- Grammar and usage tips shown by the Guiding Spirit.
CREATE TABLE IF NOT EXISTS tips (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    language_code TEXT NOT NULL REFERENCES languages(code),
    tip           TEXT NOT NULL
);

-- Culture Showcase Gallery. language_code is '' for items shared by a region;
-- image is the picture's name in assets/culture/ (without .png).
CREATE TABLE IF NOT EXISTS culture_items (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    region_code   TEXT NOT NULL REFERENCES regions(code),
    language_code TEXT NOT NULL DEFAULT '',
    kind          TEXT NOT NULL,
    title         TEXT NOT NULL,
    description   TEXT NOT NULL,
    image         TEXT NOT NULL DEFAULT ''
);

-- Regional stories unlocked by restoring a Language Core.
-- region_code 'pearl' is the final story unlocked by restoring all cores.
CREATE TABLE IF NOT EXISTS stories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    region_code TEXT NOT NULL,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL
);

-- Every quiz the player finished (passed or failed).
CREATE TABLE IF NOT EXISTS quiz_attempts (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL REFERENCES languages(code),
    difficulty    INTEGER NOT NULL,
    category_code TEXT NOT NULL DEFAULT '',
    score         INTEGER NOT NULL,
    correct       INTEGER NOT NULL,
    total         INTEGER NOT NULL,
    hearts_left   INTEGER NOT NULL,
    passed        INTEGER NOT NULL,
    played_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_attempts_user ON quiz_attempts(user_id);

-- Best result per player / language / difficulty. Drives unlocking.
CREATE TABLE IF NOT EXISTS progress (
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL REFERENCES languages(code),
    difficulty    INTEGER NOT NULL,
    best_score    INTEGER NOT NULL DEFAULT 0,
    completed     INTEGER NOT NULL DEFAULT 0,
    lesson_done   INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, language_code, difficulty)
);

-- Collected rewards: word_fragment, phrase_crystal, cultural_relic.
CREATE TABLE IF NOT EXISTS rewards (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind    TEXT NOT NULL,
    amount  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, kind)
);

-- Languages a player bought with Word Fragments (the first language of each
-- region is free and not listed here).
CREATE TABLE IF NOT EXISTS unlocked_languages (
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL,
    unlocked_at   TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, language_code)
);

-- Culture items a player has unlocked, by title (culture_items is reloaded
-- whenever the content changes). source is 'quiz:<language code>' for items
-- revealed by passing a level, or 'bought' for items bought with crystals.
CREATE TABLE IF NOT EXISTS unlocked_culture (
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    source      TEXT NOT NULL DEFAULT '',
    unlocked_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, title)
);

-- Tutorial pages a player has already seen ("welcome", "map", "quiz", ...).
CREATE TABLE IF NOT EXISTS tutorial_seen (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key     TEXT NOT NULL,
    PRIMARY KEY (user_id, key)
);

-- Badges such as core_luzon, core_visayas, core_mindanao, pearl.
CREATE TABLE IF NOT EXISTS badges (
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code      TEXT NOT NULL,
    earned_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, code)
);
