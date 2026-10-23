"""Record the Philippine-language voice clips with SapinSapin's Orpheus models.

SapinSapin (github.com/sapinsapin/halohalo) trained one Orpheus 3B voice
model per Philippine language on the Philippine Language Dataset: recordings
of real native speakers. Their own test (the speech is transcribed again by
their speech recognition) found these voices far easier to understand than
the other models they compared. This script uses them for every Philippine
word, sentence and Filipino spirit line in the game:

  Tagalog and Filipino   sapinsapin/orpheus-3b-0.1-pretrained-char-pld-fil
  Ilocano                ...-pld-ilo      Cebuano and Bisaya   ...-pld-ceb
  Kapampangan            ...-pld-pam      Hiligaynon           ...-pld-hil
  Bikolano               ...-pld-bcl      Waray-Waray          ...-pld-war
  Tausug                 ...-pld-tsg

There is no Chavacano model, so Chavacano and the English lines keep the
Kokoro voice of make_spirit_voices.py (pass --english orpheus to use
SapinSapin's Philippine-English model for English too).

Each model speaks with the voice of a speaker from its own recordings, so
every spirit has a speaker per language, picked in database/spirits.json
("voice" -> "orpheus" -> language -> list of speaker ids, the first is used).
Run --audition first: it records a greeting with every listed speaker into
tools/voice/samples/orpheus/ so you can listen and put the best one first.

Every clip is checked: generation that runs on or stops early is recorded
again (up to 3 tries). With --check, the clip is also transcribed by
SapinSapin's speech recognition for that language, and the take with the
fewest wrong letters is kept; clips that are still hard to understand are
listed in tools/voice/orpheus_report.json.

The clips are written over the same files listed in assets/voice/manifest.json,
so the game needs no other change.

Needs a computer with an NVIDIA GPU (about 8 GB of video memory) or Google
Colab (free T4 GPU), internet access to huggingface.co, ffmpeg, and:
    pip install torch transformers peft accelerate snac soundfile kokoro-onnx
The models (about 7 GB) are downloaded once by Hugging Face.

Run from the project root:
    python tools/voice/make_spirit_voices_orpheus.py --audition
    python tools/voice/make_spirit_voices_orpheus.py --check
Other options: --langs tl,ceb (only these languages), --dry-run (show what
would be recorded, no model needed), --batch 8.

The SapinSapin models and their dataset are for research and non-commercial
use (CC-BY-NC 4.0): fine for a school project, not for a game that is sold.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_spirit_voices as kokoro_voices  # noqa: E402  (same jobs, keys and file names)

ROOT = kokoro_voices.ROOT
OUT = kokoro_voices.OUT
SAMPLES = os.path.join(kokoro_voices.SAMPLES, "orpheus")
REPORT = os.path.join(ROOT, "tools", "voice", "orpheus_report.json")

BASE_MODEL = "unsloth/orpheus-3b-0.1-pretrained"
ADAPTER = "sapinsapin/orpheus-3b-0.1-pretrained-char-pld-{}"
JUDGE = "sapinsapin/whisper-small-pld-{}"
SNAC_MODEL = "hubertsiuzdak/snac_24khz"
SNAC_SR = 24000

# The game's language code -> SapinSapin's model language.
PLD_LANG = {"tl": "fil", "fil": "fil", "ilo": "ilo", "pam": "pam", "bcl": "bcl", "ceb": "ceb",
            "bis": "ceb", "hil": "hil", "war": "war", "tsg": "tsg", "en": "eng"}

# Orpheus special tokens and audio token layout (from halohalo's finetune_orpheus.py).
SOH, EOT, EOH = 128259, 128009, 128260
SOAI, SOS = 128261, 128257
EOS_SPEECH = 128258
AUDIO_BASE = 128266
CODEBOOK_STRIDE = 4096
PAD = 128263
DELIM = "|"
PUNCT_RE = re.compile(r"[^\w\s']")
TRIES = 3
MAX_SEGMENT = 110  # letters; longer text is said sentence by sentence and joined
GAP = 0.22         # seconds of silence between the joined sentences


def frontend_char(text: str) -> str:
    """The text spelled out letter by letter, words split by "|": the "char"
    notation these models were trained on ("Salamat po" -> "s a l a m a t | p o")."""
    out = []
    for i, w in enumerate(PUNCT_RE.sub("", text.lower()).split()):
        if i:
            out.append(DELIM)
        out.extend(list(w))
    return " ".join(out)


def plain(text: str) -> str:
    """Lowercase, no accents or punctuation: how a transcript is compared."""
    text = "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", text)).strip()


def cer(ref: str, hyp: str) -> float:
    """Share of letters that are wrong (edit distance / length of the text)."""
    a, b = plain(ref), plain(hyp)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1] / max(1, len(a))


def plausible(text: str, seconds: float) -> bool:
    """Rejects takes that stopped early or ran on (babbling, long silence)."""
    letters = len(plain(text).replace(" ", ""))
    return 0.25 <= seconds <= 2.5 + 0.22 * letters


def segments(text: str) -> list:
    """Long text split at sentence ends (then commas) into pieces the model says in one go."""
    if len(text) <= MAX_SEGMENT:
        return [text]
    parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", text) if p.strip()]
    out = []
    for part in parts:
        if len(part) <= MAX_SEGMENT:
            out.append(part)
            continue
        cur = ""
        for piece in re.split(r"(?<=[,;:])\s+", part):
            if cur and len(cur) + len(piece) + 1 > MAX_SEGMENT:
                out.append(cur)
                cur = piece
            else:
                cur = f"{cur} {piece}".strip()
        if cur:
            out.append(cur)
    return out


def speaker_for(spirit: dict, pld: str) -> str:
    ids = spirit["voice"].get("orpheus", {}).get(pld) or []
    if not ids:
        sys.exit(f"No Orpheus speaker for '{pld}' in database/spirits.json for {spirit['name']}.")
    return ids[0]


# ---------------------------------------------------------------- models

class Orpheus:
    def __init__(self, device: str):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
        self.torch = torch
        self.device = device
        dtype = torch.bfloat16 if torch.cuda.is_available() and torch.cuda.is_bf16_supported() else torch.float16
        if device == "cpu":
            dtype = torch.float32
        print(f"Loading {BASE_MODEL} ({dtype}) ...", flush=True)
        self.tok = AutoTokenizer.from_pretrained(BASE_MODEL)
        self.model = AutoModelForCausalLM.from_pretrained(BASE_MODEL, dtype=dtype).to(device).eval()
        from snac import SNAC
        self.snac = SNAC.from_pretrained(SNAC_MODEL).eval().to(device)
        self.loaded = set()
        self.judges = {}

    def use(self, pld: str) -> None:
        from peft import PeftModel
        repo = ADAPTER.format(pld)
        if not self.loaded:
            print(f"Loading {repo} ...", flush=True)
            self.model = PeftModel.from_pretrained(self.model, repo, adapter_name=pld).eval()
        elif pld not in self.loaded:
            print(f"Loading {repo} ...", flush=True)
            self.model.load_adapter(repo, adapter_name=pld)
        self.loaded.add(pld)
        self.model.set_adapter(pld)

    def generate(self, items: list) -> list:
        """items: [(speaker, text)] -> [(waveform at 24 kHz, finished)]."""
        torch = self.torch
        prompts = []
        for speaker, text in items:
            ids = self.tok(f"{speaker}: {frontend_char(text)}", add_special_tokens=False).input_ids
            prompts.append([SOH] + ids + [EOT, EOH, SOAI, SOS])
        width = max(len(q) for q in prompts)
        input_ids = torch.full((len(prompts), width), PAD, dtype=torch.long)
        attn = torch.zeros((len(prompts), width), dtype=torch.long)
        for i, q in enumerate(prompts):  # left padding, so every prompt ends at the same place
            input_ids[i, width - len(q):] = torch.tensor(q, dtype=torch.long)
            attn[i, width - len(q):] = 1
        with torch.inference_mode():
            gen = self.model.generate(input_ids.to(self.device), attention_mask=attn.to(self.device),
                                      max_new_tokens=1400, do_sample=True, temperature=0.6, top_p=0.9,
                                      repetition_penalty=1.1, eos_token_id=EOS_SPEECH, pad_token_id=PAD)
        out = []
        for i in range(len(items)):
            tokens = gen[i, width:].tolist()
            finished = EOS_SPEECH in tokens
            if finished:
                tokens = tokens[:tokens.index(EOS_SPEECH)]
            out.append((self.decode(tokens), finished))
        return out

    def decode(self, tokens: list):
        import numpy as np
        torch = self.torch
        tokens = [t for t in tokens if t >= AUDIO_BASE]
        frames = len(tokens) // 7
        if frames == 0:
            return np.zeros(0, dtype=np.float32)
        c0, c1, c2 = [], [], []
        for j in range(frames):
            v = [(t - AUDIO_BASE - i * CODEBOOK_STRIDE) % CODEBOOK_STRIDE for i, t in enumerate(tokens[7 * j:7 * j + 7])]
            c0.append(v[0])
            c1 += [v[1], v[4]]
            c2 += [v[2], v[3], v[5], v[6]]
        codes = [torch.tensor(c, dtype=torch.int32, device=self.device)[None] for c in (c0, c1, c2)]
        with torch.inference_mode():
            audio = self.snac.decode(codes)
        return audio[0, 0].float().cpu().numpy()

    def transcribe(self, pld: str, wav) -> str:
        import librosa
        from transformers import WhisperForConditionalGeneration, WhisperProcessor
        if pld not in self.judges:
            print(f"Loading {JUDGE.format(pld)} ...", flush=True)
            proc = WhisperProcessor.from_pretrained(JUDGE.format(pld))
            judge = WhisperForConditionalGeneration.from_pretrained(JUDGE.format(pld)).to(self.device).eval()
            self.judges[pld] = (proc, judge)
        proc, judge = self.judges[pld]
        audio = librosa.resample(wav, orig_sr=SNAC_SR, target_sr=16000)
        feats = proc(audio, sampling_rate=16000, return_tensors="pt").input_features.to(self.device, judge.dtype)
        with self.torch.inference_mode():
            ids = judge.generate(feats, language="english" if pld == "eng" else "tagalog",
                                 task="transcribe", max_new_tokens=200)
        return proc.batch_decode(ids, skip_special_tokens=True)[0]


def save_clip(wav, path: str, speed: float = 1.0) -> None:
    """Same finishing as the Kokoro clips: trimmed, even loudness, small .ogg."""
    import soundfile as sf
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "clip.wav")
        sf.write(src, wav, SNAC_SR)
        filters = ["silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
                   "silenceremove=start_periods=1:start_threshold=-45dB,areverse",
                   "highpass=f=70", "loudnorm=I=-16:TP=-1.5", "apad=pad_dur=0.08"]
        if abs(speed - 1.0) > 0.01:
            filters.insert(1, f"atempo={speed:.3f}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "24000",
                        "-af", ",".join(filters), "-c:a", "libvorbis", "-q:a", "5", path], check=True)


def record_batch(engine: Orpheus, pld: str, jobs: list, check: bool, report: list) -> None:
    """jobs: [(speaker, text, path, speed)]. Each sentence keeps the best of up to TRIES takes."""
    import numpy as np
    engine.use(pld)
    pieces = [(j, speaker, seg) for j, (speaker, text, _, _) in enumerate(jobs) for seg in segments(text)]
    best = [None] * len(pieces)  # (score, wav)
    todo = list(range(len(pieces)))
    for attempt in range(TRIES):
        if not todo:
            break
        results = engine.generate([(pieces[i][1], pieces[i][2]) for i in todo])
        still = []
        for i, (wav, finished) in zip(todo, results):
            seg = pieces[i][2]
            ok = finished and plausible(seg, len(wav) / SNAC_SR)
            score = 9.0 if not ok else (cer(seg, engine.transcribe(pld, wav)) if check else 0.0)
            if best[i] is None or score < best[i][0]:
                best[i] = (score, wav)
            if score > (0.15 if check else 0.0):
                still.append(i)
        todo = still
    gap = np.zeros(int(GAP * SNAC_SR), dtype=np.float32)
    for j, (speaker, text, path, speed) in enumerate(jobs):
        takes = [best[i] for i in range(len(pieces)) if pieces[i][0] == j]
        score = max(t[0] for t in takes)
        if score >= 9.0:
            report.append({"text": text, "lang": pld, "speaker": speaker, "problem": "no good take", "file": path})
            print(f"  ! kept the old clip: {text}")
            continue
        parts = []
        for k, (_, wav) in enumerate(takes):
            if k:
                parts.append(gap)
            parts.append(np.asarray(wav, dtype=np.float32))
        save_clip(np.concatenate(parts), path, speed)
        if check and score > 0.3:
            report.append({"text": text, "lang": pld, "speaker": speaker, "cer": round(score, 3), "file": path})
        print(f"  {os.path.relpath(path, ROOT)}  {('CER %.2f  ' % score) if check else ''}{text}")


# ---------------------------------------------------------------- main

def plan(seed: dict, spirits: dict, langs: set, english: str) -> dict:
    """pld language -> [(speaker, text, path, speed)] for every clip Orpheus records."""
    by_lang = {}
    for key, (region, lang, text) in sorted(kokoro_voices.jobs_from_content(seed, spirits).items()):
        if lang == "en" and english != "orpheus":
            continue
        if lang not in PLD_LANG or (langs and lang not in langs):
            continue
        pld = PLD_LANG[lang]
        spirit = spirits[region]
        name = kokoro_voices.hashlib.md5(key.encode("utf-8")).hexdigest()[:12] + ".ogg"
        path = os.path.join(OUT, region, name)
        speed = float(spirit["voice"].get("orpheus_speed", 1.0))
        by_lang.setdefault(pld, []).append((speaker_for(spirit, pld), text, path, speed))
    return by_lang


def audition(engine: Orpheus, seed: dict, spirits: dict, langs: set) -> None:
    """A greeting and a lesson sentence with every listed speaker of every language."""
    region_of = {l["code"]: l["region_code"] for l in seed["languages"]}
    for region, spirit in spirits.items():
        for pld, speakers in spirit["voice"].get("orpheus", {}).items():
            codes = [c for c, p in PLD_LANG.items() if p == pld and region_of.get(c) == region]
            if langs and not (set(codes) & langs) and not (pld == "fil" and "fil" in langs):
                continue
            texts = [spirit["lines"]["greet"][0][0]] if pld == "fil" else []
            texts += [s["native"] for s in seed["sentences"] if s["language_code"] in codes][:1]
            if not texts:
                continue
            engine.use(pld)
            for speaker in speakers:
                for k, text in enumerate(texts):
                    wav, finished = engine.generate([(speaker, text)])[0]
                    path = os.path.join(SAMPLES, f"{spirit['name'].lower()}_{pld}_{speaker}_{k + 1}.ogg")
                    save_clip(wav, path)
                    print(f"{os.path.relpath(path, ROOT)}  | {text}{'' if finished else '  (cut off)'}")
    print("Listen to the samples, then put the best speaker first for each language in database/spirits.json.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--langs", default="", help="only these game languages, e.g. tl,ceb,fil")
    ap.add_argument("--english", choices=["kokoro", "orpheus"], default="kokoro")
    ap.add_argument("--audition", action="store_true", help="record each listed speaker, to choose voices")
    ap.add_argument("--check", action="store_true", help="transcribe every take and keep the clearest")
    ap.add_argument("--dry-run", action="store_true", help="list what would be recorded")
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--device", default="cuda")
    args = ap.parse_args()

    with open(kokoro_voices.SEED, encoding="utf-8") as f:
        seed = json.load(f)
    with open(kokoro_voices.SPIRITS, encoding="utf-8") as f:
        spirits = json.load(f)["spirits"]
    langs = {l.strip() for l in args.langs.split(",") if l.strip()}

    by_lang = plan(seed, spirits, langs, args.english)
    if args.dry_run:
        with open(os.path.join(OUT, "manifest.json"), encoding="utf-8") as f:
            listed = {v.replace("res://", "") for v in json.load(f).values()}
        missing = [p for jobs in by_lang.values() for _, _, p, _ in jobs if os.path.relpath(p, ROOT) not in listed]
        if missing:
            print(f"{len(missing)} clips are not in assets/voice/manifest.json: run make_spirit_voices.py first.")
        long = [(t, len(segments(t))) for jobs in by_lang.values() for _, t, _, _ in jobs if len(segments(t)) > 1]
        print(f"{len(long)} long lines are said in parts (up to {max([n for _, n in long] or [1])} parts).")
        for pld, jobs in by_lang.items():
            print(f"{ADAPTER.format(pld)}: {len(jobs)} clips")
            for speaker, text, path, _ in jobs[:3]:
                print(f"    {speaker}: {frontend_char(text)}  -> {os.path.relpath(path, ROOT)}")
        print(f"{sum(len(j) for j in by_lang.values())} clips in all")
        return 0

    engine = Orpheus(args.device)
    if args.audition:
        audition(engine, seed, spirits, langs)
        return 0
    report = []
    for pld, jobs in by_lang.items():
        print(f"{pld}: {len(jobs)} clips", flush=True)
        for k in range(0, len(jobs), args.batch):
            record_batch(engine, pld, jobs[k:k + args.batch], args.check, report)
    with open(REPORT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    print(f"Done. {len(report)} clips to listen to again are listed in {os.path.relpath(REPORT, ROOT)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
