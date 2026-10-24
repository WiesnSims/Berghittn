class_name PatchNotes
extends RefCounted
## What changed in each version (user request 2026-10-24), newest first, short and for players: a
## line per change, not the details. The version itself is application/config/version in
## project.godot; a new one gets its entry here at the top. 1.1 is M9.
## The text is not in the translation tables: each entry carries both languages.

const ENTRIES: Array[Dictionary] = [
	{
		"version": "1.2", "date": "2026-10-25",
		"en": [
			"Die Bsundan: six rare special enemies, each with its own look, hat and trick, worth 3× the points.",
			"Da Vereinskassier collects your membership fee with every blow. Get it back from his Kassa!",
			"Da Sprengmeister carries dynamite: shoot him early, or in the middle of a crowd.",
			"Die Schönperchte blesses the enemies around her. Shoot her Tafel off!",
			"Da Influencer goes live: the enemies near him get faster, and his ring light dazzles.",
			"Da Bergführer brings his Seilschaft on a rope, and da Trailrunner charges straight at you.",
			"Da Huatständer: every kind of hat you shoot off hangs in the Stube, under the Trophäenwand.",
			"Steckbriefe & Wandernadln on the title screen: a wanted poster for every enemy you have met, and 18 badges to earn.",
			"\"Bsundane Woch!\": a new event that brings the Bsundan far more often for a wave. The other enemies greet them, too.",
			"The last kill of a wave plays in slow motion (it can be switched off in Settings).",
			"The end screen and the Gipfelbuch count the Bsundan you killed.",
		],
		"de": [
			"Die Bsundan: sechs seltene Spezialgegner mit eigenem Aussehen, Hut und Trick, für die dreifachen Punkte.",
			"Da Vereinskassier kassiert mit jedem Schlag den Mitgliedsbeitrag. Hol ihn dir aus seiner Kassa zurück!",
			"Da Sprengmeister hat Dynamit dabei: früh erwischen, oder mitten in der Menge.",
			"Die Schönperchte segnet die Gegner um sie herum. Schieß ihr die Tafel runter!",
			"Da Influencer geht live: die Gegner bei ihm werden schneller, und sein Ringlicht blendet.",
			"Da Bergführer bringt seine Seilschaft am Seil mit, und da Trailrunner rennt geradewegs auf dich zu.",
			"Da Huatständer: Jede Art Hut, die du abschießt, hängt in der Stube, unter der Trophäenwand.",
			"Steckbriefe & Wandernadln im Hauptmenü: ein Steckbrief für jeden Gegner, dem du begegnet bist, und 18 Abzeichen zum Sammeln.",
			"\"Bsundane Woch!\": ein neues Ereignis, bei dem eine Welle lang viel öfter Bsundane kommen. Die anderen Gegner begrüßen sie auch.",
			"Der letzte Kill einer Welle läuft in Zeitlupe (in den Einstellungen abschaltbar).",
			"Der Endbildschirm und das Gipfelbuch zählen die Bsundan, die du erlegt hast.",
		],
	},
	{
		"version": "1.1.3", "date": "2026-10-24",
		"en": [
			"Huat obschiaßn: shoot the hats off the Wanderer, Tourist, Knappe, Wilderer and Venedigermandl for 20 points. They won't be happy about it.",
		],
		"de": [
			"Huat obschiaßn: Schieß dem Wanderer, Touristen, Knappen, Wilderer und Venedigermandl den Hut vom Kopf, für 20 Punkte. Begeistert sind sie davon nicht.",
		],
	},
	{
		"version": "1.1.2", "date": "2026-10-24",
		"en": [
			"Balance: forged guns carry less spare ammo, their right-click modes use more rounds, and their ammo costs more.",
			"Stumpf: a doppelt dengelt weapon goes dull after 150 kills. Sharpen it again at the Dengelstock for half the price.",
			"Sitzfleisch: whoever stays in one spot too long during a wave gets visitors.",
			"Settings: key bindings for every action, field of view, aiming by toggle, the crosshair's colour and size, and antialiasing (FXAA, MSAA 2×/4×).",
			"Six new title screen pictures, taking turns.",
			"Main menu: from the pause menu and the end screen, which also opens the Gipfelbuch.",
		],
		"de": [
			"Balance: geschmiedete Waffen tragen weniger Reservemunition, ihr Rechtsklick braucht mehr Schuss, und ihre Munition kostet mehr.",
			"Stumpf: eine doppelt dengelte Waffe wird nach 150 Abschüssen stumpf. Am Dengelstock um den halben Preis wieder schärfen lassen.",
			"Sitzfleisch: Wer während einer Welle zu lang an einem Fleck hockt, kriegt Besuch.",
			"Einstellungen: Tastenbelegung für jede Aktion, Sichtfeld, Zielen per Umschalten, Farbe und Größe des Fadenkreuzes, und Kantenglättung (FXAA, MSAA 2×/4×).",
			"Sechs neue Bilder im Titelbildschirm, die sich abwechseln.",
			"Hauptmenü: aus dem Pausenmenü und vom Endbildschirm, der auch das Gipfelbuch öffnet.",
		],
	},
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
