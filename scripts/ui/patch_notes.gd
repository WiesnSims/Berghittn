class_name PatchNotes
extends RefCounted
## What changed in each version (user request 2026-10-24), newest first, short and for players: a
## line per change, not the details. The version itself is application/config/version in
## project.godot; a new one gets its entry here at the top. 1.1 is M9.
## The text is not in the translation tables: each entry carries both languages.

const ENTRIES: Array[Dictionary] = [
	{
		"version": "1.1.1", "date": "2026-10-24",
		"en": [
			"Das Gipfelbuch: the global leaderboard on the title screen, Solo and Co-op, all time and this week.",
			"Your runs are signed in automatically, and the end screen shows your place (switch it off in Settings).",
		],
		"de": [
			"Das Gipfelbuch: die weltweite Bestenliste im Titelbildschirm, Solo und Gemeinsam, Allzeit und diese Woche.",
			"Deine Runden werden automatisch eingetragen, und der Endbildschirm zeigt deinen Platz (abschaltbar in den Einstellungen).",
		],
	},
	{
		"version": "1.1", "date": "2026-10-24",
		"en": [
			"Nomoi!: play again with the same group in one click, and the Hüttenwertung after a co-op match.",
			"Hits and kills you can feel, damage numbers (Settings) and dialect kill streaks with bonus points.",
			"The enemies talk (Settings: Enemy chatter).",
			"Da Dengelstock in the Holzschuppen's hay loft: forge your guns and special weapons, twice over.",
			"New: das Venedigermandl, a little gold digger who runs off with his sack. Catch him!",
			"New enemies: da Wilderer with his old rifle (take cover when his scope glints), and flocks of Bergdohlen.",
		],
		"de": [
			"Nomoi!: mit der gleichen Runde mit einem Klick nochmal spielen, und die Hüttenwertung nach einem Koop-Spiel.",
			"Treffer und Kills, die man spürt, Schadenszahlen (Einstellungen) und Kill-Serien im Dialekt mit Bonuspunkten.",
			"Die Gegner reden (Einstellungen: Gegner reden).",
			"Da Dengelstock auf dem Heuboden im Holzschuppen: schmiede deine Waffen und Spezialwaffen, zweimal.",
			"Neu: das Venedigermandl, ein kleiner Goldgräber, der mit seinem Sack davonläuft. Fang ihn!",
			"Neue Gegner: da Wilderer mit seinem alten Gewehr (in Deckung, wenn sein Zielfernrohr blitzt) und Schwärme von Bergdohlen.",
		],
	},
	{
		"version": "1.0.1", "date": "2026-10-24",
		"en": [
			"New: stuffed animals and trophies in the Stube, hats to earn, the Trophäenwand.",
			"New: the death screen shows your kills, headshots, favourite weapon, Schnaps and personal best.",
			"New: die Kraxn in the Matratzenlager, a third weapon slot.",
			"Repetierer: a real lever action, loads round by round, and a new right click, the Querschläger.",
			"Stutzen: bullets go through enemies again.",
			"Die Resi plays fair: the enemies come 5 s later and need 3 hits to chase her off.",
			"Harmonika and the Rodelkanone's Kehre rebalanced.",
			"Gmiatlichkeit no longer makes you nearly unkillable in a swarm.",
			"Three boring hats removed.",
		],
		"de": [
			"Neu: ausgestopfte Tiere und Trophäen in der Stube, Hüte zum Freispielen, die Trophäenwand.",
			"Neu: der Todesbildschirm zeigt Kills, Kopfschüsse, Lieblingswaffe, Schnaps und deinen Rekord.",
			"Neu: die Kraxn im Matratzenlager, ein dritter Waffenplatz.",
			"Repetierer: echter Unterhebel, lädt Patrone für Patrone, und neu auf Rechtsklick: der Querschläger.",
			"Stutzen: die Kugeln gehen wieder durch die Gegner.",
			"Die Resi spielt fair: die Gegner kommen 5 s später und brauchen 3 Treffer, bis sie davonläuft.",
			"Harmonika und die Kehre der Rodelkanone neu abgestimmt.",
			"Gmiatlichkeit macht dich im Gedränge nicht mehr fast unverwundbar.",
			"Drei langweilige Hüte entfernt.",
		],
	},
	{
		"version": "1.0", "date": "2026-10-19",
		"en": [
			"Game release!",
			"Hold the Berghütte against endless waves: Wanderer, Tourists, Bergknappen, Perchten and the Krampus.",
			"Six rooms to open, from the Stube to the Seilbahn, and windows to board up.",
			"Guns on the walls, the Hüttentruhe, and special weapons from the Alphorn to the Rodelkanone.",
			"Schnaps perks, the Brettljause, and visitors: die Resi, the Bierfassl, the Murmeltier, the Deitscha Tourist.",
			"Co-op for up to four in the browser.",
		],
		"de": [
			"Das Spiel ist da!",
			"Halt die Berghütte gegen endlose Wellen: Wanderer, Touristen, Bergknappen, Perchten und den Krampus.",
			"Sechs Räume zum Aufsperren, von der Stube bis zur Seilbahn, und Fenster zum Vernageln.",
			"Waffen an den Wänden, die Hüttentruhe und Spezialwaffen vom Alphorn bis zur Rodelkanone.",
			"Schnaps-Perks, die Brettljause und Besuch: die Resi, das Bierfassl, das Murmeltier, der Deitscha Tourist.",
			"Koop für bis zu vier im Browser.",
		],
	},
]


## The game's version (project.godot).
static func current() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0"))


## Every entry as text for a RichTextLabel (BBCode), newest first, in the game's language.
static func as_text() -> String:
	var german: bool = TranslationServer.get_locale().begins_with("de")
	var parts: PackedStringArray = []
	for entry: Dictionary in ENTRIES:
		var lines: PackedStringArray = []
		lines.append("[font_size=28][b]%s[/b][/font_size]  [color=#b8b0a4]%s[/color]" % [entry["version"], entry["date"]])
		for line: String in entry["de" if german else "en"]:
			lines.append("[indent]•  %s[/indent]" % line)
		parts.append("\n".join(lines))
	return "\n\n".join(parts)
