# LinguaPinas

**An Educational Game for Philippine Languages**, made with Godot 4, SQLite and
MarianNMT. Capstone project by Norbencent A. Dagalea, Angel T. Kadusali and
Rolan E. Andrade, Don Jose Ecleo Memorial College.

The player is a *Language Guardian* who restores the three Language Cores
(Luzon, Visayas, Mindanao) by studying lessons and passing quizzes. Restoring
all three unlocks **The Pearl of the Orient**.

## Running the game

1. Install **Godot 4.4** or newer (standard build, not .NET): <https://godotengine.org/download>
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run). The game opens in a phone-shaped portrait window.

## Building the Android app

The game is a portrait (720x1280) Android-style app and already has an
Android export preset (`export_presets.cfg`, package `com.linguapinas.game`).

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Install Android Studio (or the Android SDK command-line tools) and OpenJDK 17,
   then set their paths in **Editor → Editor Settings → Export → Android**.
   Godot can create the debug keystore for you.
3. **Project → Export → Android → Export Project** to get `build/LinguaPinas.apk`,
   or connect your phone with USB debugging on and press the Android
   "Remote Debug" button to install it directly.

The game is fully offline. The SQLite database is created automatically on
first launch at `user://linguapinas.db`:

| OS | Location |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\LinguaPinas\linguapinas.db` |
| macOS | `~/Library/Application Support/Godot/app_userdata/LinguaPinas/linguapinas.db` |
| Linux | `~/.local/share/godot/app_userdata/LinguaPinas/linguapinas.db` |

You can open it with [DB Browser for SQLite](https://sqlitebrowser.org/) to
inspect players, scores and progress. Delete the file to reset the game.

## Game flow (follows the prototype screens)

Title (**START / SETTING**) → **NEW GAME / CONTINUE / SETTING** → Enter your
name (pick a hero) → **Main Island** map (tap Luzon, Visayas or Mindanao) →
island page with its guide (Maelor, Marea, Lanora) and heroes → language list
→ **EASY / MEDIUM / HARD** → lesson (Aralin) → quiz (**TANONG**, options A-D,
**I-TSEK**, five hearts, tap the guide for a hint) → results, rewards and
badges, saved to SQLite. The **HOME / GALLERY / BACK / PROFILE** bar is at the
bottom of every screen.

**Settings** has the interface language (Filipino or English), music volume,
sound-effects volume and notifications (the in-game pop-up notices), saved in
the database.

## Art

The pictures in `assets/ui` (background, logo, gem buttons, title ribbon,
frame, map, heroes, guides, quiz scene, navigation bar) were cut out of the
prototype slide screenshots, so they are low resolution. For sharper
graphics, replace those PNG files with your original artwork, using the same
file names. `tools/art/extract_prototype_art.py` shows how each one was cut.
The language maps (`assets/ui/lang_map_luzon.png`, `lang_map_visayas.png`,
`lang_map_mindanao.png`) are shown on each island's language list; tap one to
see it full screen. Quiz backgrounds are in `assets/quiz_scenes` and the
warrior sprite sheets in `assets/enemies`.
Fonts: Cinzel, Cinzel Decorative and Lilita One (SIL Open Font License, see
`assets/fonts/OFL.txt`). The
music and sound effects in `assets/audio` were generated for this project.

## Features

| Feature | Status |
| --- | --- |
| Portrait Android layout with the prototype art (title, menu, name entry, settings, map, island pages, profile, gallery, quiz) | Implemented |
| New Game (name, optional password, choose a hero) / Continue (saved players) | Implemented (salted SHA-256 password hashes, stored locally) |
| Settings: Filipino/English interface, music and SFX volume, notifications | Implemented |
| Profile with name, island, language, fragments, crystals, relics, badges, score, playtime | Implemented |
| First-time tutorial: the first launch points at START, NEW GAME and the name card; each new player then sees an 8-page welcome story on the map, followed by a guided tour where an animated hand points at what to tap next while the Guiding Spirit explains it (map → island → language → level → lesson → quiz → results). SKIP TUTORIAL any time | Implemented (scripts/autoload/tutorial.gd, scripts/ui/guide_pages.gd), remembered per player in the database |
| Guide (GABAY button on the map): every topic and the reward guide, with REPLAY TUTORIAL and "show all tips again"; the Gallery and Guiding Spirit show a short tip on the first visit | Implemented |
| Region selection: Luzon, Visayas, Mindanao | Implemented |
| 30 languages listed (10 per region) | Implemented |
| Lessons and quizzes with content | Implemented for 10 languages: Tagalog, Ilocano, Kapampangan, Bikolano, Cebuano, Hiligaynon, Waray-Waray, Bisaya, Tausug, Chavacano. The other 20 show "Coming soon". |
| Pre-quiz lessons (vocabulary, sentences, situations, grammar tips) | Implemented |
| Easy: vocabulary multiple choice (both directions) | Implemented |
| Medium: sentence building, dialogue selection, comprehension | Implemented |
| Hard: context-based "what would you say", sentence building with decoy words, typed recall | Implemented |
| Pronunciation help from the Guiding Spirit (BIGKAS button in quizzes, PRONOUNCE in the Guiding Spirit screen): syllables, stressed syllable, sound tips, LISTEN with the device's text-to-speech voice | Implemented (no native recordings or speech recognition yet) |
| Grammar quiz per language (pick the correct sentence, fill in the missing marker or pronoun, write sentences) | Implemented: opens after Easy, earns Phrase Crystals |
| Grammar checker (spelling, missing / extra words, word order, with the matching grammar tip) | Implemented in the grammar quiz and in the Guiding Spirit screen; it compares with the game's sentence bank |
| Easy: picture matching | Not implemented (needs image assets) |
| Word categories (Greetings, Family, Food, Nature, Numbers, Expressions) | Implemented: category lessons and Easy practice quizzes |
| Levels unlock in order (Easy → Medium → Hard) | Implemented |
| Five-heart system; review the lesson after losing all hearts | Implemented |
| Rewards: Word Fragments (Easy), Phrase Crystals (Medium, Grammar), Cultural Relics (Hard) | Implemented: a first clear pays in full, replays and practice pay half |
| Spending rewards | 20 Word Fragments unlock a language (the first language of each island is free); 5 Phrase Crystals unlock a culture item; 1 Cultural Relic buys an extra hint when free hints run out |
| Island pearls (Luzon, Visayas, Mindanao Pearl) and the Pearl of the Orient, with a light-up animation (rays, rings of light, sparkles) when a pearl is lit; the map shows each island's progress (e.g. 2/4) | Implemented |
| Culture Showcase Gallery (food, festivals, clothing, textiles, art, dances, music, crafts, heritage) | Implemented: 46 cultural elements, at least one for each of the 30 languages, each with a picture. Clearing a level for the first time reveals one (shown on the Results screen); the rest can be unlocked with Phrase Crystals. Lessons show the language's unlocked culture |
| Culture questions in quizzes | Implemented: 1 per Easy quiz, 2 per Medium and Hard quiz, from the language's and region's culture items |
| Stories unlocked by lighting the island pearls | Implemented: one story per region plus the Pearl story |
| Leaderboard (all players on the device, filter by region) | Implemented |
| Guiding Spirits with their own personality and voice: Maelor (Luzon, a wise elder who loves proverbs), Marea (Visayas, a cheerful sea spirit) and Lanora (Mindanao, a calm weaver of stories). They greet you, react to every answer, give hints, celebrate and comfort you, and say every lesson word and sentence in their own recorded voice | Implemented (database/spirits.json, assets/voice/, SPIRIT VOICE switch in Settings) |
| Talk to your Guiding Spirit (chat): "How do I say thank you?", "What does kumusta mean?", "Pronounce salamat", "Is this correct: gusto ko tubig", "Tell me about Sinulog", "What should I do next?", in English or Filipino. Answers offline from the dictionary, pronunciation helper, grammar checker, culture items and your progress | Implemented (scripts/spirit_brain.gd) |
| Guiding Spirit: offline dictionary, word-by-word gloss, grammar tips, quiz hints | Implemented |
| Guiding Spirit: MarianNMT machine translation | Implemented as an optional local server (see below) |
| Text-to-speech (Coqui TTS / Tacotron2), TensorFlow Lite / ONNX on device | Not implemented |

An island's pearl lights up only when the player has mastered every playable
language of that island (Easy, Medium and Hard passed in each):
Tagalog, Ilocano, Kapampangan and Bikolano for Luzon; Cebuano, Hiligaynon and
Waray-Waray for the Visayas; Bisaya, Tausug and Chavacano for Mindanao. When
more languages get lessons, they are added to the requirement automatically
(`is_core_restored` in `scripts/autoload/db.gd`). Lighting all three unlocks
the Pearl of the Orient. Only "All categories" quizzes unlock levels and count
on the leaderboard; category practice still earns rewards.

## Spirit voices

The spirits' voices are recorded with eSpeak NG by
`tools/voice/make_spirit_voices.py` (Philippine languages are read with its
Indonesian voice, which follows the same spelling rules; Chavacano with its
Spanish voice). Each spirit has its own pitch, speed and voice in
`database/spirits.json`. After changing lessons or lines, run the script
again. To use native speakers' recordings instead, save an `.ogg` over the
clip listed for that text in `assets/voice/manifest.json`. Text without a
clip (free answers in the chat) is read by the device's own voice, tuned to
the spirit, when the device has one.

## MarianNMT (optional)

The Guiding Spirit answers from the SQLite dictionary first. For free-form
translation, run the local MarianNMT server described in
[`tools/marian_server/README.md`](tools/marian_server/README.md). It runs on
`127.0.0.1:5005`, needs Python, and works offline after the models are
downloaded once. If the server is not running, the game says so and keeps
using the dictionary.

## Project structure

```
project.godot              Godot project (main scene: scenes/title.tscn, portrait 720x1280)
export_presets.cfg         Android export preset
assets/ui, fonts, audio    UI art and language maps, fonts, music and sound effects
assets/quiz_scenes         Quiz background scenes
assets/enemies             Warrior sprite sheets per region
addons/godot-sqlite/       SQLite GDExtension v4.5 (Windows, macOS, Linux, Android)
database/schema.sql        Database tables
database/seed_data.json    All learning content: languages, words, sentences, tips, culture, stories
scripts/autoload/db.gd     SQLite access: accounts, content, progress, rewards, leaderboard
scripts/autoload/game.gd   Session state, navigation, quiz generation and scoring
scripts/autoload/spirit.gd Guiding Spirit translator (dictionary + MarianNMT)
scripts/autoload/ui.gd     Prototype look: theme, page frame, banner, nav bar, Filipino/English text
scripts/autoload/sound.gd  Music and sound effects
scripts/ui/gem_button.gd   Gem button that keeps its diamond ends when stretched
scripts/screens/*.gd       One script per screen (scenes/*.tscn)
tests/test_runner.tscn     Automated test
tools/marian_server/       Optional MarianNMT translation server (Python)
```

## Culture pictures

The Gallery pictures in `assets/culture/` are illustrated placeholder cards
drawn by `tools/art/make_culture_cards.py`. To use a real photo or drawing,
save it over the card with the same file name (for example
`assets/culture/sinulog.png`); any size works. Running the script again
only draws cards that are missing, so your pictures are kept (use `--all`
to redraw every card).

## Adding or fixing content

All lessons come from `database/seed_data.json`. To add a language's
content, add its `words`, `sentences` (with an optional `context` for Hard
questions) and `tips`, set the language's `"playable": 1`, then **increase
`"version"`**. On next launch the game reloads the content without erasing
players or progress.

> The starter vocabulary is a small sample. Have native speakers check it
> before using the game in class.

## Running the tests

```bash
godot --headless --import          # first time only
godot --headless --path . res://tests/test_runner.tscn
```

The test uses a separate database. It checks seeding, accounts, quiz
generation for every language and level, unlocking, rewards, badges, the
leaderboard and translation, then plays full quizzes through the real quiz
screen.

## Exporting

Use **Project → Export** in Godot (install export templates first). The
SQLite addon includes binaries for Windows, macOS, Linux and Android.

## Credits

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) (MIT)
- [Helsinki-NLP OPUS-MT](https://github.com/Helsinki-NLP/Opus-MT) MarianNMT models
