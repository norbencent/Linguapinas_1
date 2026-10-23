"""Record the Guiding Spirits' voices with eSpeak NG.

Every word and sentence of the lessons (database/seed_data.json) is recorded
in the voice of its island's spirit, and every line in database/spirits.json
is recorded in Filipino and English. The clips go to assets/voice/<island>/
as small .ogg files, listed in assets/voice/manifest.json, so the spirits
speak the same way on every computer and phone, with no internet.

The clips are spoken by MBROLA voices through eSpeak NG: clearer and more
natural than eSpeak's own voices. There is no Tagalog voice, so the
Philippine languages are read with the Indonesian voice (mb-id1), which
follows the same spelling rules (ng, clear vowels, syllables), Chavacano with
a Spanish voice and the spirits' English lines with an American voice. Each
spirit has its own voices, pitch, speed and, for the female spirits, a pitch
shift (database/spirits.json, "voice": "ph", "es", "en"). Every clip is
cleaned up (silence trimmed, loudness evened out, a soft echo for the spirit).
Without MBROLA the plain eSpeak voices are used instead.

Native recordings can replace any clip: save an .ogg over the file listed for
that text in manifest.json.

Run from the project root:   python tools/voice/make_spirit_voices.py
Needs: espeak-ng, mbrola and ffmpeg (Ubuntu: apt install espeak-ng ffmpeg
mbrola mbrola-id1 mbrola-us1 mbrola-us2 mbrola-es1 mbrola-es3; Windows:
install eSpeak NG with MBROLA voices, and ffmpeg, and put them on PATH)
Pass --all to record every clip again (by default existing clips are kept).
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "voice")
SEED = os.path.join(ROOT, "database", "seed_data.json")
SPIRITS = os.path.join(ROOT, "database", "spirits.json")

# Which of the spirit's voices reads each kind of text: "ph" for the
# Philippine languages and the spirits' Filipino lines, "es" for Chavacano,
# "en" for the English lines.
READ_WITH = {"cbk": "es", "en": "en"}
DEFAULT_READER = "ph"
# Plain eSpeak voices used when MBROLA is not installed.
ESPEAK_FALLBACK = {"ph": "id", "es": "es", "en": "en-us"}


def normalize(text: str) -> str:
    """Same as Game.normalize_answer in the game."""
    out = "".join(ch for ch in text.lower() if ch not in "?!.,'’`-")
    return " ".join(out.split())


def clip_key(region: str, lang: str, text: str) -> str:
    return f"{region}|{lang}|{normalize(text)}"


def _speak(text: str, voice: str, pitch: int, speed: int, wav: str) -> bool:
    """eSpeak NG (with an MBROLA voice if voice starts with "mb-"). True if audio came out."""
    r = subprocess.run(["espeak-ng", "-v", voice, "-p", str(pitch), "-s", str(speed), "-g", "1", "-w", wav, text],
                       capture_output=True)
    return r.returncode == 0 and os.path.exists(wav) and os.path.getsize(wav) > 2000


def record(text: str, reader: str, voice: dict, path: str) -> None:
    v = voice[reader]
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "clip.wav")
        shift = float(v.get("shift", 1.0))
        if not _speak(text, v["voice"], v["pitch"], v["speed"], wav):
            # No MBROLA (or it could not say this text): the plain eSpeak voice.
            shift = 1.0
            _speak(text, f"{ESPEAK_FALLBACK[reader]}+{voice['espeak_variant']}", v["pitch"], v["speed"], wav)
        filters = ["silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                   "silenceremove=start_periods=1:start_threshold=-50dB,areverse"]
        if shift != 1.0:
            filters.append(f"rubberband=pitch={shift}")
        filters += ["highpass=f=80", "lowpass=f=7600", "aecho=0.85:0.5:45:0.12", "loudnorm=I=-16:TP=-1.5",
                    "apad=pad_dur=0.08"]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-ar", "22050",
                        "-af", ",".join(filters), "-c:a", "libvorbis", "-q:a", "4", path], check=True)


def main() -> int:
    redo = "--all" in sys.argv
    with open(SEED, encoding="utf-8") as f:
        seed = json.load(f)
    with open(SPIRITS, encoding="utf-8") as f:
        spirits = json.load(f)["spirits"]
    region_of = {l["code"]: l["region_code"] for l in seed["languages"]}

    jobs = {}  # key -> (region, reader, text)
    for row in seed["words"] + seed["sentences"]:
        lang = row["language_code"]
        region = region_of[lang]
        texts = [row["native"]] + [p.strip() for p in row["native"].split("/") if "/" in row["native"]]
        for text in texts:
            if normalize(text):
                jobs[clip_key(region, lang, text)] = (region, READ_WITH.get(lang, DEFAULT_READER), text)
    for region, spirit in spirits.items():
        for pair in [spirit["about"]] + [l for lines in spirit["lines"].values() for l in lines]:
            for lang, text in zip(("fil", "en"), pair):
                jobs[clip_key(region, lang, text)] = (region, READ_WITH.get(lang, DEFAULT_READER), text)

    manifest = {}
    made = 0
    for key, (region, reader, text) in sorted(jobs.items()):
        folder = os.path.join(OUT, region)
        os.makedirs(folder, exist_ok=True)
        name = hashlib.md5(key.encode("utf-8")).hexdigest()[:12] + ".ogg"
        path = os.path.join(folder, name)
        if redo or not os.path.exists(path):
            record(text, reader, spirits[region]["voice"], path)
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
