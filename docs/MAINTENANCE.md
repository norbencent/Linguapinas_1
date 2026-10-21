# LINGUAPINAS maintenance guide

For developers who correct, update or move the game. Setup for running and
exporting is in the [README](../README.md).

## How the game is put together

The game is a Godot 4 project written in GDScript. Every screen is built in
code by one script; shared work is done by six autoloads (always-loaded
singletons), started in this order:

| Autoload | File | Job |
| --- | --- | --- |
| `DB` | `scripts/autoload/db.gd` | The only code that talks to SQLite: players, lessons, progress, rewards, culture, leaderboard, data checks and backups |
| `Game` | `scripts/autoload/game.gd` | The current player and language, screen navigation and the back key, quiz building and scoring, display settings, leave warnings, break reminder |
| `Spirit` | `scripts/autoload/spirit.gd` | Guiding Spirits: personalities, recorded voices, translation (dictionary, optional MarianNMT) |
| `Sound` | `scripts/autoload/sound.gd` | Music and sound effects |
| `UI` | `scripts/autoload/ui.gd` | The look of the game: theme, page frame, buttons, nav bar, Filipino/English text |
| `Tutorial` | `scripts/autoload/tutorial.gd` | The first-time hand tour |

```
Screen script (scripts/screens/*.gd)
   │  builds its page with UI.page(), UI.label(), UI.gem_button() ...
   │  reads and saves data only through DB.*
   │  moves to other screens with Game.goto("name") / Game.BACK
   ▼
DB (db.gd) ── SQL ──► user://linguapinas.db (SQLite, via addons/godot-sqlite)
   ▲
   └── content loaded from database/seed_data.json, tables from database/schema.sql
```

Other folders:

- `scripts/ui/`: reusable pieces (gem button, battle stage, pearl animation,
  pronunciation panel, guide pages).
- `scripts/spirit_brain.gd`: the Guiding Spirit chat (offline).
- `scenes/*.tscn`: one tiny scene per screen; each only attaches its script.
  The screen names are listed in `Game.SCENES`.
- `database/spirits.json`: the spirits' lines and voice settings.
- `assets/`: pictures, fonts, sounds and recorded voices.
- `tools/`: Python scripts that make the art cards and record voices.
- `tests/test_runner.gd`: the automated test.

## Dependencies

| Needed for | What |
| --- | --- |
| Running and exporting | Godot 4.4 or newer, standard build (made with 4.5.1) |
| Database | godot-sqlite 4.5 GDExtension, included in `addons/godot-sqlite` (Windows, macOS, Linux, Android binaries) |
| Android build | Godot Android export templates, Android SDK, OpenJDK 17 |
| Recording spirit voices (optional) | Python 3, eSpeak NG, ffmpeg (`tools/voice/make_spirit_voices.py`) |
| Culture placeholder cards (optional) | Python 3 with Pillow (`tools/art/make_culture_cards.py`) |
| Free translation (optional) | Python MarianNMT server (`tools/marian_server`) |

## Moving the project to another computer

1. Copy the whole folder (or clone the repository). Nothing outside it is needed.
2. Install Godot 4.4 or newer, open `project.godot` with **Import**.
3. Run once with F5, or headless: `godot --headless --import`.
4. Run the test (below) to confirm everything works on the new computer.

Players' saved data is not in the project folder: it is in Godot's user data
folder (see the README table). To move a player's progress, copy
`linguapinas.db` (and the `backups` folder) to the same place on the other
device.

## Updating lessons and other content

Everything a learner reads comes from `database/seed_data.json`. Code does not
need to change.

| To change | Edit in seed_data.json |
| --- | --- |
| A word | `words`: `language_code`, `category_code`, `native`, `english`, `note` |
| A sentence | `sentences`: `native`, `english`, optional `context` (used by Hard questions) |
| A grammar tip | `tips` |
| A cultural element | `culture_items` (picture: `assets/culture/<image>.png`) |
| A story | `stories` |
| Make a language playable | its entry in `languages`: `"playable": 1`, then add its words, sentences and tips |

Then **increase `"version"`** at the top of the file. On the next start the game
reloads the content and keeps every player's progress. After changing words or
sentences, run `python tools/voice/make_spirit_voices.py` to record the new
clips (optional: without a clip, the device voice is used).

Wrong or unclear content is fixed the same way: correct the entry and raise
the version. The quiz questions are built from the content each time, so they
update automatically.

## Saved data, integrity and backups

- Tables are in `database/schema.sql`; new columns are added by `_migrate()`
  in `db.gd`, so old saves keep working.
- Changes that touch several tables run in one transaction.
- On every start, SQLite checks the file (`PRAGMA quick_check`); a damaged file
  is replaced by the newest good backup and the player is told.
- A backup is made every day and before a player is deleted, in
  `user://backups/` (the newest 7 are kept).
- `DB.verify_data()` runs the full check: file structure, links between
  tables, and the game's rules. `DB.restore_backup(path)` restores a backup
  (the current data is backed up first); there is no in-game button for it.

## Finding and fixing problems

- Run the test after every change:
  `godot --headless --path . res://tests/test_runner.tscn`. It plays the game
  through its real screens and prints each failed check.
- SQL errors are printed with the query that failed (`DB._exec`).
- Open `linguapinas.db` in DB Browser for SQLite to look at the saved data.
- Each screen's code is in the script with the same name as its scene.

## Known limitations

- Spirit voices are synthesized with eSpeak NG; native-speaker recordings can
  replace any clip (`assets/voice/manifest.json`).
- 10 of the 30 listed languages have lessons; the other 20 appear on the maps.
- There is no speech recognition: the game shows and plays pronunciation but
  does not grade the player's voice.
- Free translation needs the optional MarianNMT server; without it the
  built-in dictionary answers.
- Progress is stored on one device; there is no online account or sync.
