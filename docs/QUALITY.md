# How LINGUAPINAS meets the ISO/IEC 25010 quality characteristics

Each characteristic is matched with what the game does and where it is
checked by the automated test (`tests/test_runner.gd`).

| Characteristic | In the game | Checked by the test |
| --- | --- | --- |
| **Functional suitability** | Lessons and quizzes for 10 languages at three levels; hints, BIGKAS pronunciation, grammar quiz and checker; culture gallery; rewards that unlock languages, culture and hints; island pearls; immediate right/wrong feedback with the Guiding Spirit's explanation. | Quiz generation for every language and level, full quizzes played through the screens, rewards, unlocks, culture, pearls |
| **Performance efficiency** | Screens are built in code from small images; content is read from a local SQLite database. | Every screen must open in under 2 seconds |
| **Compatibility** | Works offline on Android and on computers (Windows, macOS, Linux); scales to any screen size; music, sounds and voices pause when another app is in front and resume afterwards; audio never blocks an activity. | The game runs headless; background pause and resume |
| **Interaction capability** | First-time hand tour and the GABAY guide with a Getting Started checklist; Filipino or English interface; large buttons; the same HOME / GALLERY / BACK / PROFILE bar everywhere; the phone's back key works on every screen. | Tutorial steps, guide topics, back navigation on every screen |
| **Reliability** | Progress is saved after every lesson and quiz, in transactions; the database is checked on every start and restored from a backup if damaged; a full data check (`DB.verify_data()`) verifies the file, the links between tables and the game's rules. | Data check, detection of a bad row, recovery of a damaged save |
| **Security** | Only a name and a hero are asked for; nothing leaves the device; optional passwords are stored only as salted SHA-256 hashes; other screens show only names and scores; deleted data is overwritten (secure delete); each player's progress is kept separate. | Hashed passwords, secure delete, separate players |
| **Maintainability** | One script per screen, all database work in `db.gd`, all content in `seed_data.json`, an automated test, and `docs/MAINTENANCE.md` (structure, dependencies, limitations). | The whole test suite |
| **Flexibility** | Lessons, culture and stories are changed in one JSON file without changing code; new languages are turned on with `"playable": 1`; sound is adjustable; the project moves to another computer by copying the folder (`docs/MAINTENANCE.md`). | Content reload without duplicates, settings |
| **Safety** | Leaving a quiz half-way asks first; a backup is made before a player is deleted; a break reminder every 30 minutes; content is educational and age-appropriate; damaged saves are restored automatically. | Leave warning (STAY and LEAVE), backup before delete and restore, break reminder |
