"""Enemy voice lines, "Gredn" (M9 part 3): every line spoken by eSpeak NG and run through an undead
filter per enemy type. The filters are the ones the user approved from the samples (2026-10-23):
the Wanderer and the Tourist clean (no breath hiss), the Knappe, the Perchte and the Krampus as first
sampled.

eSpeak NG (GPL-3) is only a tool on the dev machine, never shipped; the audio it makes is ours.
    winget install --id eSpeak-NG.eSpeak-NG -e      (or set ESPEAK to the espeak-ng executable)

The shown text of each line lives in scripts/enemies/gredn.gd; here is how it is spoken (spelt for
eSpeak's German, which reads the dialect closely enough). Each line is one sound,
assets/audio/sfx/gredn_<name>_1.ogg."""
import os
import shutil
import subprocess
import tempfile

import numpy as np
import soundfile as sf
from scipy import signal

import dsp as d
import sfx

SR = d.SR


def espeak() -> str:
    """The espeak-ng executable, or "" when it is not installed."""
    for path in (os.environ.get("ESPEAK", ""), shutil.which("espeak-ng") or "",
                 "C:/Program Files/eSpeak NG/espeak-ng.exe", "C:/Program Files (x86)/eSpeak NG/espeak-ng.exe"):
        if path and os.path.isfile(path):
            return path
    return ""


def speak(text, voice, speed, pitch):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    try:
        subprocess.run([espeak(), "-v", voice, "-s", str(speed), "-p", str(pitch), "-w", path, text],
                       check=True, capture_output=True)
        x, sr = sf.read(path)
    finally:
        os.remove(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    return x, sr


def at_pitch(x, sr, factor):
    """Resampled to SR so it plays `factor` x higher (and faster)."""
    return signal.resample(x, int(round(len(x) * SR / sr / factor)))


def envelope(x, cutoff=30.0):
    return d.lowpass(np.abs(x), cutoff)


def vocode(mod, carrier, bands=24, lo=80.0, hi=7000.0):
    """Channel vocoder: the speech's spectrum shape on our own growl."""
    edges = np.geomspace(lo, hi, bands + 1)
    out = np.zeros_like(mod)
    for a, b in zip(edges[:-1], edges[1:]):
        env = envelope(d.bandpass(mod, a, b, 2), 40.0)
        out += d.bandpass(carrier, a, b, 2) * np.maximum(env, 0)
    return out


def rasp(x, amount):
    """Breath noise riding on the voice's loudness: a dry, dead throat."""
    env = np.maximum(envelope(x, 25.0), 0)
    return x + d.bandpass(d.noise(len(x) / SR), 900, 5000) * env * amount


def finish(x, room=0.18, seconds=0.9):
    x = d.reverb(d.normalize(x), seconds, room)
    return d.fade(d.normalize(d.trim(x), 0.85), 0.005, 0.05)


# --- one filter per enemy type ---------------------------------------------------------------------

def wanderer(text):
    """Low, slow, a little muffled and warm, a soft saturation; no hiss."""
    x, sr = speak(text, "de+m3", 125, 25)
    x = at_pitch(x, sr, 0.82)
    x = d.lowpass(d.drive(d.normalize(x), 1.3), 3200) + 0.25 * d.lowpass(x, 300)
    return finish(x, 0.15)


def tourist(text):
    """Quick, a bit higher, thin like a phone speaker; no hiss."""
    x, sr = speak(text, "de+m1", 175, 60)
    x = at_pitch(x, sr, 0.92)
    x = d.bandpass(d.drive(d.normalize(x), 1.3), 250, 4500)
    return finish(x, 0.12)


def knappe(text):
    """Very deep, rasping, echoing down the mine shaft."""
    x, sr = speak(text, "de+m2", 150, 15)
    x = at_pitch(x, sr, 0.7)
    x = d.drive(d.normalize(rasp(x, 1.5)), 2.5)
    x = d.lowpass(x, 2600)
    return finish(d.echo(x, 0.19, 0.3, 3), 0.3, 1.6)


def perchte(text):
    """A whisper over a trembling growl."""
    x, sr = speak(text, "de+whisper", 140, 50)
    x = at_pitch(x, sr, 0.85)
    t = np.arange(len(x)) / SR
    s = len(x) / SR
    growl = sfx.voice(s, 55.0, [(0, "a"), (s, "o")], 0.8, 0.3, 0.06, 0.6, 2.5)
    x = d.normalize(x) + 0.5 * vocode(d.normalize(x), growl)
    x = x * (1.0 + 0.4 * np.sin(2 * np.pi * 31 * t))
    return finish(d.drive(d.normalize(x), 2.2), 0.2)


def krampus(text):
    """Very deep, on a growl, in a big room."""
    x, sr = speak(text, "de+m3", 150, 10)
    x = at_pitch(x, sr, 0.62)
    s = len(x) / SR
    carrier = sfx.voice(s, 48.0, [(0, "o"), (s, "a")], 0.7, 0.25, 0.04, 0.9, 3.0)
    x = 0.55 * d.normalize(x) + vocode(d.normalize(x), carrier)
    x = d.lowpass(d.drive(d.normalize(x), 3.0), 3000)
    return finish(x, 0.3, 1.8)


# Sound id -> (filter, how eSpeak is to say it). Every id is used by a line in gredn.gd.
LINES = {
    "gredn_wanderer_griass_di": (wanderer, "Griaß di. Griaß di."),
    "gredn_wanderer_huettn": (wanderer, "Is no weit bis zur Hüttn?"),
    "gredn_wanderer_hunger": (wanderer, "I hob an Hunger."),
    "gredn_wanderer_fuass": (wanderer, "Mei Fuaß."),
    "gredn_wanderer_huettnwirt": (wanderer, "Mach auf, i bins, da Hüttnwirt!"),
    "gredn_wanderer_servas": (wanderer, "Servas."),
    "gredn_tourist_foto": (tourist, "Nur no a Foto!"),
    "gredn_tourist_gipfelglueck": (tourist, "Hashtag Gipfelglück!"),
    "gredn_tourist_wlan": (tourist, "Wo is des WLAN?"),
    "gredn_tourist_frei": (tourist, "Hallo? Is des Zimmer no frei?"),
    "gredn_tourist_bewertung": (tourist, "Aua! Des gibt a schlechte Bewertung!"),
    "gredn_tourist_tschuess": (tourist, "Tschüss!"),
    "gredn_knappe_glueck_auf": (knappe, "Glück auf!"),
    "gredn_knappe_eini": (knappe, "Do gehts eini!"),
    "gredn_knappe_fels": (knappe, "Des is a weicher Fels."),
    "gredn_knappe_geh_bitte": (knappe, "Geh bitte."),
    "gredn_knappe_schicht": (knappe, "Schicht is."),
    "gredn_perchte_hoe": (perchte, "Hö! Hö! Hö!"),
    "gredn_perchte_kimmst": (perchte, "Jetzt kimmst!"),
    "gredn_krampus_brav": (krampus, "Warst a brav?"),
    "gredn_krampus_sackl": (krampus, "In mei Sackl mit dir!"),
    "gredn_krampus_buessn": (krampus, "Des wirst ma büßn!"),
    "gredn_krampus_joahr": (krampus, "I kimm wieder. Nächsts Joahr!"),
}


def _recipe(fn, text):
    return lambda v: fn(text)


# name -> (recipe, variants), like sfx.SOUNDS.
SOUNDS = {name: (_recipe(fn, text), 1) for name, (fn, text) in LINES.items()}
