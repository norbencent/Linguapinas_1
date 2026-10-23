"""Record the Guiding Spirits' voices with the Kokoro neural voice.

Every word and sentence of the lessons (database/seed_data.json) is recorded
in the voice of its island's spirit, and every line in database/spirits.json
is recorded in Filipino and English. The clips go to assets/voice/<island>/
as small .ogg files, listed in assets/voice/manifest.json, so the spirits
speak the same way on every computer and phone, with no internet.

The voices come from Kokoro (82M, Apache-2.0), a neural text-to-speech model
that sounds like a real person, not a robot. Each spirit has its own Kokoro
voice and speed (database/spirits.json, "voice": "kokoro", "speed"):

  Maelor (Luzon)    am_michael  warm, calm man (the grandfather)
  Marea (Visayas)   af_heart    bright, cheerful woman
  Lanora (Mindanao) af_bella    soft, gentle woman (the storyteller)

Kokoro has no Philippine language, so Philippine words are not read as
English. phonemes() below turns Philippine spelling into the sounds of the
language (IPA): clear vowels, "ng" as one sound, a tapped r, the glottal
stop, and stress on the second-to-last syllable unless an accent mark says
otherwise. Kokoro then speaks those exact sounds in the spirit's voice.
Chavacano is read with Kokoro's Spanish rules and English lines as English.

Native recordings can replace any clip: save an .ogg over the file listed for
that text in manifest.json.

Run from the project root:   python tools/voice/make_spirit_voices.py
Needs: pip install kokoro-onnx soundfile, and ffmpeg. The model files
(kokoro-v1.0.onnx, voices-v1.0.bin, about 350 MB) are downloaded once into
tools/voice/models/ from github.com/thewh1teagle/kokoro-onnx/releases.
Pass --all to record every clip again (by default existing clips are kept),
or --sample to record a few lines of each spirit into tools/voice/samples/.
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "voice")
SEED = os.path.join(ROOT, "database", "seed_data.json")
SPIRITS = os.path.join(ROOT, "database", "spirits.json")
MODELS = os.path.join(ROOT, "tools", "voice", "models")
SAMPLES = os.path.join(ROOT, "tools", "voice", "samples")
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
MODEL_FILES = ["kokoro-v1.0.onnx", "voices-v1.0.bin"]

# ---------------------------------------------------------------- Philippine spelling -> sounds

VOWELS = "aeiou"
ACCENTS = {"á": "a", "à": "a", "â": "a", "é": "e", "è": "e", "ê": "e", "í": "i", "ì": "i", "î": "i",
           "ó": "o", "ò": "o", "ô": "o", "ú": "u", "ù": "u", "û": "u"}
VOWEL_SOUND = {"a": "a", "e": "ɛ", "i": "i", "o": "o", "u": "u"}
# Consonant spellings, longest first.
CONSONANTS = [("ng", "ŋ"), ("ch", "tʃ"), ("sh", "ʃ"), ("ts", "tʃ"), ("ll", "lj"), ("qu", "k"), ("ñ", "ɲ"),
              ("b", "b"), ("d", "d"), ("f", "f"), ("g", "ɡ"), ("h", "h"), ("j", "dʒ"), ("k", "k"), ("l", "l"),
              ("m", "m"), ("n", "n"), ("p", "p"), ("r", "ɾ"), ("s", "s"), ("t", "t"), ("v", "b"), ("w", "w"),
              ("x", "ks"), ("y", "j"), ("z", "s")]
# Little words with their own pronunciation.
SPECIAL = {"ng": "naŋ", "mga": "maˈŋa"}


def _units(word: str):
    """Spelling -> [(sound, is_vowel, accented)], with a glottal stop for '-' and "'"."""
    out = []
    i = 0
    while i < len(word):
        ch = word[i]
        if ch in "-'’":
            out.append(("ʔ", False, False))
            i += 1
            continue
        if ch in ACCENTS or ch in VOWELS:
            base = ACCENTS.get(ch, ch)
            # Two identical vowels (e.g. "saan") have a glottal stop between them.
            if out and out[-1][1] and out[-1][0] == VOWEL_SOUND[base]:
                out.append(("ʔ", False, False))
            out.append((VOWEL_SOUND[base], True, ch in ACCENTS))
            i += 1
            continue
        if ch == "c":  # Spanish spelling: c before e/i is s, otherwise k
            nxt = word[i + 1] if i + 1 < len(word) else ""
            if nxt == "h":
                out.append(("tʃ", False, False))
                i += 2
            else:
                out.append(("s" if nxt in "eiéí" else "k", False, False))
                i += 1
            continue
        for spelling, sound in CONSONANTS:
            if word.startswith(spelling, i):
                out.append((sound, False, False))
                i += len(spelling)
                break
        else:
            i += 1  # anything else (digits, symbols) is skipped
    return out


def word_phonemes(word: str) -> str:
    w = unicodedata.normalize("NFC", word.lower())
    if w in SPECIAL:
        return SPECIAL[w]
    units = _units(w)
    nuclei = [k for k, u in enumerate(units) if u[1]]
    if not nuclei:
        return "".join(u[0] for u in units)
    # Each syllable starts with the consonant just before its vowel.
    starts = [0]
    for a, b in zip(nuclei, nuclei[1:]):
        gap = b - a - 1
        starts.append(b if gap == 0 else b - 1)
    accented = [k for k, n in enumerate(nuclei) if units[n][2]]
    if accented:
        stressed = accented[0]
    else:
        stressed = max(0, len(nuclei) - 2)
        # A word ending in a glottal stop or consonant cluster keeps the usual stress.
    out = []
    for k, start in enumerate(starts):
        end = starts[k + 1] if k + 1 < len(starts) else len(units)
        syl = "".join(u[0] for u in units[start:end])
        out.append(("ˈ" if k == stressed and len(nuclei) > 1 else "") + syl)
    return "".join(out)


def phonemes(text: str) -> str:
    """A Philippine-language word or sentence -> the sounds Kokoro speaks."""
    out = []
    word = ""
    for ch in unicodedata.normalize("NFC", text) + " ":
        if ch.isalpha() or ch in "-'’":
            word += ch
            continue
        if word:
            out.append(word_phonemes(word.strip("-'’") if word.strip("-'’") else word))
            word = ""
        if ch in ",.!?;:":
            out.append(ch)
        elif ch in "/":
            out.append(",")
        elif ch.isspace() and out and out[-1] != " ":
            out.append(" ")
    s = "".join(out).strip()
    for p in ",.!?;:":
        s = s.replace(" " + p, p)
    if s and s[-1] not in ".!?":
        s += "."
    return s


# ---------------------------------------------------------------- clips

def normalize(text: str) -> str:
    """Same as Game.normalize_answer in the game."""
    out = "".join(ch for ch in text.lower() if ch not in "?!.,'’`-")
    return " ".join(out.split())


def clip_key(region: str, lang: str, text: str) -> str:
    return f"{region}|{lang}|{normalize(text)}"


def load_kokoro():
    from kokoro_onnx import Kokoro
    os.makedirs(MODELS, exist_ok=True)
    for name in MODEL_FILES:
        path = os.path.join(MODELS, name)
        if not os.path.exists(path):
            print("Downloading", name, "...")
            urllib.request.urlretrieve(MODEL_URL + name, path + ".part")
            os.replace(path + ".part", path)
    return Kokoro(os.path.join(MODELS, MODEL_FILES[0]), os.path.join(MODELS, MODEL_FILES[1]))


def speak(kokoro, text: str, lang: str, voice: dict):
    """Audio samples and sample rate of [text] in the spirit's voice."""
    speed = float(voice.get("speed", 1.0))
    if lang == "en":
        return kokoro.create(text, voice=voice["kokoro"], speed=speed, lang="en-us")
    if lang == "cbk":
        return kokoro.create(text, voice=voice["kokoro"], speed=speed, lang="es")
    # Single words a little slower, so learners hear every sound.
    if len(text.split()) <= 2:
        speed *= 0.92
    return kokoro.create(phonemes(text), voice=voice["kokoro"], speed=speed, is_phonemes=True)


def record(kokoro, text: str, lang: str, voice: dict, path: str) -> None:
    import soundfile as sf
    samples, rate = speak(kokoro, text, lang, voice)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "clip.wav")
        sf.write(wav, samples, rate)
        filters = ["silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                   "silenceremove=start_periods=1:start_threshold=-50dB,areverse",
                   "highpass=f=70", "loudnorm=I=-16:TP=-1.5", "apad=pad_dur=0.08"]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-ar", "24000",
                        "-af", ",".join(filters), "-c:a", "libvorbis", "-q:a", "5", path], check=True)


def jobs_from_content(seed: dict, spirits: dict) -> dict:
    region_of = {l["code"]: l["region_code"] for l in seed["languages"]}
    jobs = {}  # key -> (region, lang, text)
    for row in seed["words"] + seed["sentences"]:
        lang = row["language_code"]
        region = region_of[lang]
        texts = [row["native"]] + [p.strip() for p in row["native"].split("/") if "/" in row["native"]]
        for text in texts:
            if normalize(text):
                jobs[clip_key(region, lang, text)] = (region, lang, text)
    for region, spirit in spirits.items():
        for pair in [spirit["about"]] + [l for lines in spirit["lines"].values() for l in lines]:
            for lang, text in zip(("fil", "en"), pair):
                jobs[clip_key(region, lang, text)] = (region, lang, text)
    return jobs


def samples(kokoro, seed: dict, spirits: dict) -> None:
    os.makedirs(SAMPLES, exist_ok=True)
    first = {r: next(l["code"] for l in seed["languages"] if l["region_code"] == r and l.get("playable")) for r in spirits}
    for region, spirit in spirits.items():
        lines = [("fil", spirit["lines"]["greet"][0][0]), ("en", spirit["lines"]["greet"][0][1])]
        lang = first[region]
        words = [w["native"] for w in seed["sentences"] if w["language_code"] == lang][:2]
        lines += [(lang, w) for w in words]
        for k, (lang, text) in enumerate(lines):
            path = os.path.join(SAMPLES, f"{spirit['name'].lower()}_{k + 1}_{lang}.ogg")
            record(kokoro, text, lang, spirit["voice"], path)
            print(path, "|", text)


def main() -> int:
    with open(SEED, encoding="utf-8") as f:
        seed = json.load(f)
    with open(SPIRITS, encoding="utf-8") as f:
        spirits = json.load(f)["spirits"]
    kokoro = load_kokoro()
    if "--sample" in sys.argv:
        samples(kokoro, seed, spirits)
        return 0
    redo = "--all" in sys.argv
    manifest = {}
    made = 0
    for key, (region, lang, text) in sorted(jobs_from_content(seed, spirits).items()):
        folder = os.path.join(OUT, region)
        os.makedirs(folder, exist_ok=True)
        name = hashlib.md5(key.encode("utf-8")).hexdigest()[:12] + ".ogg"
        path = os.path.join(folder, name)
        if redo or not os.path.exists(path):
            record(kokoro, text, lang, spirits[region]["voice"], path)
            made += 1
        manifest[key] = f"res://assets/voice/{region}/{name}"
    # Remove clips no longer used.
    keep = {os.path.basename(v) for v in manifest.values()}
    for region in spirits:
        folder = os.path.join(OUT, region)
        for f in os.listdir(folder) if os.path.isdir(folder) else []:
            if f.endswith(".ogg") and f not in keep:
                os.remove(os.path.join(folder, f))
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=0, sort_keys=True)
    print(f"{len(manifest)} clips ({made} recorded now) in {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
