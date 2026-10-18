class_name HikerStyle
extends RefCounted
## What a player can dress their hiker in (M7, user decision Q5): a head, a hat and a colour each for
## the jacket and the trousers. A profile is a small Dictionary that goes over the network as is:
## {"name": String, "head": int, "hat": int, "jacket": int, "trousers": int}.
## tools/models/build_hiker.gd builds one mesh per head and hat, in this order.

## Name keys of the heads (assets/models/hiker.tscn parts Head0..Head4).
const HEADS: Array[String] = ["UI_HEAD_BUA", "UI_HEAD_BART", "UI_HEAD_OPA", "UI_HEAD_ZOEPF", "UI_HEAD_LOCKEN"]
## Name keys of the hats; 0 is none (parts Hat1..Hat5).
const HATS: Array[String] = ["UI_HAT_NONE", "UI_HAT_TIROLER", "UI_HAT_BOMMEL", "UI_HAT_STIRNBAND", "UI_HAT_HELM", "UI_HAT_KAPPE"]
const JACKETS: Array[Color] = [
	Color(0.72, 0.14, 0.1), Color(0.16, 0.32, 0.62), Color(0.2, 0.42, 0.22), Color(0.92, 0.66, 0.12),
	Color(0.45, 0.2, 0.5), Color(0.1, 0.55, 0.6), Color(0.88, 0.42, 0.12), Color(0.2, 0.2, 0.22),
]
const TROUSERS: Array[Color] = [
	Color(0.36, 0.24, 0.13), Color(0.18, 0.2, 0.28), Color(0.28, 0.3, 0.22), Color(0.12, 0.12, 0.13),
	Color(0.5, 0.42, 0.32), Color(0.45, 0.12, 0.1),
]
const NAME_MAX_LENGTH: int = 16


## A starting profile; `peer` picks a different jacket, head and hat for each of the four players.
static func default_profile(peer: int = 1) -> Dictionary:
	var i: int = maxi(peer - 1, 0)
	return {"name": "", "head": i % HEADS.size(), "hat": (i + 1) % HATS.size(),
			"jacket": (i * 3) % JACKETS.size(), "trousers": i % TROUSERS.size()}


## Clamps whatever arrived (from a save or a peer) to a valid profile.
static func sanitize(profile: Variant) -> Dictionary:
	var out: Dictionary = default_profile()
	if not profile is Dictionary:
		return out
	var p: Dictionary = profile
	out["name"] = String(p.get("name", "")).strip_edges().left(NAME_MAX_LENGTH)
	out["head"] = clampi(int(p.get("head", 0)), 0, HEADS.size() - 1)
	out["hat"] = clampi(int(p.get("hat", 0)), 0, HATS.size() - 1)
	out["jacket"] = clampi(int(p.get("jacket", 0)), 0, JACKETS.size() - 1)
	out["trousers"] = clampi(int(p.get("trousers", 0)), 0, TROUSERS.size() - 1)
	return out


## The name shown above the hiker; a player who typed none is "Wanderer n".
static func display_name(profile: Dictionary, peer: int) -> String:
	var name: String = profile.get("name", "")
	return name if name != "" else tr_format("UI_PLAYER_N", peer)


static func tr_format(key: String, value: Variant) -> String:
	return TranslationServer.translate(key) % value
