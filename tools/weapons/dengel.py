"""The Dengelstock's weapons (M9 part 4, GAME_DESIGN section 12): writes the dengelt (level 1) and
doppelt dengelt (level 2) WeaponData of each base weapon from its .tres, so the numbers stay in data
and follow the base when it is tuned. Run it again after changing a base weapon:

    python tools/weapons/dengel.py

Level 1: damage x2 (bosses x1.5), magazine +50 % (rounded up), a deeper shot.
Level 2 doubles every effect of level 1: damage x4 (bosses x2.25), magazine +100 %.
Balance (1.1.2, players camped spamming the right-click modes): the reserve grows only to x1.25 and
x1.5 (rounded up), and the right-click mode takes x1.5 and x2 the rounds (rounded up).
Melee and special weapons: the damage, and the twist (stun_time, twist) doubled from level 1 to level 2.
tests/m9_dengel checks the files against these rules."""
import math
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
WEAPONS = os.path.join(ROOT, "data", "weapons")

# Base id -> {extra fields of level 1}; level 2 doubles the extras that are numbers.
FORGE = {
    "pistole": {},
    "jagdflinte": {},
    "stutzen": {},
    "repetierer": {},
    "schaufel": {"stun_time": 1.2},
    # The special weapons (part 4b): each its own twist, see WeaponData.twist.
    "alphorn": {"twist": 1.0},
    "knoedelwerfer": {"twist": 3.0},
    "handboeller": {"twist": 3.0},
    "rodelkanone": {"twist": 1.0},
    "harmonika": {"twist": 5.0},
    "brennkessel": {"twist": 1.5},
    "goassl": {"twist": 3.0},
    "mistgabel": {"twist": 1.0},
    "schmarrnpfanne": {"twist": 1.5},
    "krampusrute": {"twist": 3.0},
}
# Per level: damage, boss share (of that damage), magazine, reserve, right-click rounds, shot pitch.
LEVELS = {
    1: {"damage": 2.0, "boss": 0.75, "mag": 1.5, "reserve": 1.25, "rounds": 1.5, "pitch": 0.85},
    2: {"damage": 4.0, "boss": 0.5625, "mag": 2.0, "reserve": 1.5, "rounds": 2.0, "pitch": 0.75},
}
SUFFIX = {1: "dengelt", 2: "doppelt"}
# Base id -> fields of level 2 only. The Dienstpistole doppelt dengelt is the Golden Gun (an easter
# egg, user request 2026-10-24): all gold, and every hit kills. Balance 1.1.2: one round in it (no
# extra one in the chamber) and nine to spare, never refilled.
LEVEL_2_ONLY = {"pistole": {"one_hit": "true", "golden": "true", "mag_size": "1", "reserve_ammo": "9", "refillable": "false", "chamber_time": "0.0"}}


def field(text, name):
    m = re.search(r"^%s = (.*)$" % name, text, re.M)
    return m.group(1) if m else None


def set_field(text, name, value):
    if field(text, name) is not None:
        return re.sub(r"^%s = .*$" % name, "%s = %s" % (name, value), text, count=1, flags=re.M)
    # New fields go right after the id.
    return re.sub(r"^(id = .*)$", r"\1\n%s = %s" % (name, value), text, count=1, flags=re.M)


def forged(base_text, base_id, level, extras):
    k = LEVELS[level]
    text = base_text
    # Only the script and the viewmodel are shared; the next level is added below.
    text = re.sub(r'^\[ext_resource type="Resource".*\n', "", text, flags=re.M)
    text = re.sub(r"^upgrade = .*\n", "", text, flags=re.M)
    text = set_field(text, "id", '&"%s_%s"' % (base_id, SUFFIX[level]))
    name_key = field(text, "display_name").strip('"')
    text = set_field(text, "display_name", '"%s_%d"' % (name_key, level))
    text = set_field(text, "damage", str(int(field(text, "damage")) * int(k["damage"])))
    if field(text, "secondary_damage"):
        text = set_field(text, "secondary_damage", str(int(field(text, "secondary_damage")) * int(k["damage"])))
    rico = field(text, "ricochet_damage")
    if rico:
        values = [int(v) * int(k["damage"]) for v in re.findall(r"-?\d+", rico.split("(", 1)[1])]
        text = set_field(text, "ricochet_damage", "PackedInt32Array(%s)" % ", ".join(map(str, values)))
    mag = int(field(text, "mag_size") or 0)
    if mag > 0:
        text = set_field(text, "mag_size", str(math.ceil(mag * k["mag"])))
    reserve = int(field(text, "reserve_ammo") or 0)
    if reserve > 0:
        text = set_field(text, "reserve_ammo", str(math.ceil(reserve * k["reserve"])))
    rounds = int(field(text, "secondary_rounds") or 0)
    if rounds > 0:
        text = set_field(text, "secondary_rounds", str(math.ceil(rounds * k["rounds"])))
    for name, value in extras.items():
        text = set_field(text, name, repr(value * level) if isinstance(value, float) else str(value * level))
    if level == 2:
        for name, value in LEVEL_2_ONLY.get(base_id, {}).items():
            text = set_field(text, name, value)
    text = set_field(text, "sound_pitch", repr(k["pitch"]))
    text = set_field(text, "boss_multiplier", repr(k["boss"]))
    text = set_field(text, "family", '&"%s"' % base_id)
    text = set_field(text, "level", str(level))
    return text


def link(text, target_id):
    """`text` with upgrade pointing at data/weapons/<target_id>.tres."""
    text = re.sub(r'^\[ext_resource type="Resource".*\n', "", text, flags=re.M)
    text = re.sub(r"^upgrade = .*\n", "", text, flags=re.M)
    ext = '[ext_resource type="Resource" path="res://data/weapons/%s.tres" id="up"]\n' % target_id
    # After the last ext_resource line.
    lines = text.split("\n")
    last = max(i for i, line in enumerate(lines) if line.startswith("[ext_resource"))
    lines.insert(last + 1, ext.rstrip("\n"))
    text = "\n".join(lines)
    return re.sub(r"^(viewmodel = .*)$", r'\1\nupgrade = ExtResource("up")', text, count=1, flags=re.M)


def main():
    for base_id, extras in FORGE.items():
        path = os.path.join(WEAPONS, base_id + ".tres")
        with open(path, encoding="utf-8") as f:
            base = f.read()
        one = forged(base, base_id, 1, extras)
        two = forged(base, base_id, 2, extras)
        files = {
            base_id: link(base, "%s_%s" % (base_id, SUFFIX[1])),
            "%s_%s" % (base_id, SUFFIX[1]): link(one, "%s_%s" % (base_id, SUFFIX[2])),
            "%s_%s" % (base_id, SUFFIX[2]): two,
        }
        for name, text in files.items():
            with open(os.path.join(WEAPONS, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            print("wrote", name)


if __name__ == "__main__":
    main()
