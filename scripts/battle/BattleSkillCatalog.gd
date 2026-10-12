extends RefCounted
## One stable skill per collection ID, independent of owned-animal IDs or save schema.
## Entries follow chickens.json: ten characters per tier, not ten consecutive per lineage.
const MOVES := [
	"Golden Peep|bolt|haste", "Sleepy Bubble|bolt|slow", "Happy Spark|chain|heal", "Angry Pop|burst|burn", "Tiny Needle|snipe|weaken", "Belly Bounce|nova|shield", "Fluff Cloud|wave|heal", "Long-Leg Kick|beam|haste", "Shy Shell|orbit|shield", "Curious Zap|volley|stun",
	"Harvest Seeds|volley|heal", "Straw Whirl|orbit|slow", "Egg Barrage|burst|shield", "Corn Cannon|beam|burn", "Mud Splash|blast|slow", "Grass Snare|wave|poison", "Hammer Spark|bolt|stun", "Hot Soup|blast|heal", "Lasso Shot|snipe|slow", "Power Peck|bolt|execute",
	"Double Comb|volley|burn", "Stretch Beam|beam|weaken", "Round Ripple|nova|heal", "Block Breaker|burst|shield", "Third-Eye Ray|snipe|stun", "Beak Boomerang|orbit|drain", "Wing Needles|volley|poison", "Neck Lance|beam|slow", "Twin Sparks|chain|haste", "Crazy Fireworks|meteor|burn",
	"Royal Lance|beam|shield", "Shadow Shuriken|volley|poison", "Crescent Slash|wave|execute", "Thunder Axe|blast|stun", "Knockout Combo|burst|weaken", "Cannon Plunder|meteor|drain", "Piercing Arrow|snipe|poison", "Shield Ricochet|chain|shield", "War Cry|nova|haste", "Rally Volley|volley|heal",
	"Flame Comet|meteor|burn", "Tidal Wave|wave|heal", "Frost Shards|volley|slow", "Lightning Chain|chain|stun", "Quake Ring|nova|shield", "Cyclone Feathers|orbit|haste", "Thorn Seeds|burst|poison", "Boulder Cannon|bolt|weaken", "Storm Beam|beam|stun", "Lava Eruption|blast|burn",
	"Arcane Bolts|volley|weaken", "Hex Cauldron|blast|poison", "Crown Judgment|snipe|execute", "Queen's Grace|nova|heal", "Royal Star|bolt|shield", "Magic Spiral|orbit|haste", "Crystal Prism|beam|slow", "Fate Thread|chain|weaken", "Angel Feathers|wave|heal", "Demon Siphon|burst|drain",
	"Pulse Cannon|bolt|stun", "Cyber Salvo|volley|drain", "Static Broadcast|nova|weaken", "Data Virus|chain|poison", "Mecha Rockets|meteor|shield", "Rocket Rain|blast|burn", "Orbital Signal|orbit|haste", "Laser Sweep|beam|burn", "Predictive Shot|snipe|execute", "Future Wave|wave|slow",
	"Space Capsule|bolt|shield", "Alien Spores|burst|poison", "Lunar Ripples|wave|slow", "Mars Mortar|meteor|burn", "Planet Rings|orbit|shield", "Tractor Ray|beam|drain", "Meteor Shower|blast|stun", "Gravity Well|nova|slow", "Galaxy Link|chain|heal", "Cosmic Needles|volley|weaken",
	"Dragon Breath|beam|burn", "Phoenix Bloom|nova|heal", "Rainbow Lance|snipe|shield", "Hydra Spit|volley|poison", "Griffin Gale|wave|haste", "Kraken Ink|blast|weaken", "Ancient Seal|orbit|stun", "Celestial Stars|chain|heal", "Void Collapse|meteor|drain", "Chaos Rupture|burst|execute",
	"Divine Judgment|meteor|execute", "Solar Flare|nova|burn", "Moon God's Veil|wave|shield", "Time Fracture|chain|slow", "Space Rift|beam|weaken", "Universe Bloom|blast|heal", "Infinity Barrage|volley|haste", "Creation Halo|orbit|heal", "Imperial Decree|snipe|stun", "Ultimate Supernova|burst|drain",
]
const PATTERNS := {
	"bolt": {"label": "Single shot", "power": 1.9, "range": 4, "cooldown": 4.8},
	"volley": {"label": "Three shots", "power": 0.8, "range": 4, "cooldown": 6.0},
	"burst": {"label": "Triple focus", "power": 0.85, "range": 3, "cooldown": 6.4},
	"blast": {"label": "Splash radius 1", "power": 1.25, "range": 4, "cooldown": 6.8},
	"beam": {"label": "Pierce target lane", "power": 1.45, "range": 5, "cooldown": 6.6},
	"chain": {"label": "Jump to 3 foes", "power": 1.05, "range": 4, "cooldown": 6.8},
	"nova": {"label": "Ring radius 3", "power": 1.1, "range": 3, "cooldown": 7.0},
	"snipe": {"label": "Weakest foe", "power": 2.3, "range": 6, "cooldown": 7.2},
	"wave": {"label": "Wide frontal wave", "power": 1.15, "range": 4, "cooldown": 7.0},
	"orbit": {"label": "Nearest 2 foes", "power": 1.45, "range": 4, "cooldown": 6.2},
	"meteor": {"label": "Splash radius 2", "power": 1.2, "range": 5, "cooldown": 7.6},
}
const EFFECTS := {
	"burn": {"color": "ff823c", "text": "Burn: 18% ATK/sec for 3s"},
	"poison": {"color": "9ccb49", "text": "Poison: 12% ATK/sec for 5s"},
	"slow": {"color": "66d6f3", "text": "Slow: 40% slower actions for 2s"},
	"stun": {"color": "ffcf4b", "text": "Stun: stop actions for 0.6s"},
	"weaken": {"color": "bb8cde", "text": "Weaken: -25% damage for 3s"},
	"drain": {"color": "ee77b5", "text": "Drain: heal 35% of HP damage dealt"},
	"execute": {"color": "f06c69", "text": "+50% damage to foes below 35% HP"},
	"heal": {"color": "79d58c", "text": "Heal weakest ally for 120% ATK"},
	"shield": {"color": "69b7f4", "text": "Self shield: 150% ATK for 4s"},
	"haste": {"color": "ffe28c", "text": "Haste: 35% faster actions for 3s"},
}

const VISUAL_GROUPS := {
	"ice": [43, 57], "fire": [4, 30, 41, 50, 66, 74, 81, 82, 92],
	"water": [2, 15, 18, 23, 42, 86], "lightning": [3, 10, 17, 29, 34, 44, 49, 61],
	"leaf": [11, 12, 16, 47, 72, 84], "rock": [24, 45, 48, 77],
	"wind": [7, 27, 46, 59, 85],
}
const VISUAL_COLORS := {"ice": "8feaff", "fire": "ff8b38", "water": "47bbff", "lightning": "ffe65b", "leaf": "8adc55", "rock": "c6a081", "wind": "c1ffe8"}

static func for_id(asset_id: int) -> Dictionary:
	var id := clampi(asset_id, 1, 100)
	var parts := str(MOVES[id - 1]).split("|")
	var skill: Dictionary = PATTERNS[parts[1]].duplicate(true)
	skill.merge({"id": id, "name": parts[0], "pattern": parts[1], "effect": parts[2],
		"color": Color(EFFECTS[parts[2]].color), "tier": (id - 1) / 10 + 1})
	skill.cooldown = float(skill.cooldown) + float((id - 1) % 10) * 0.06
	skill["visual"] = "energy"
	for motif in VISUAL_GROUPS:
		if id in VISUAL_GROUPS[motif]:
			skill.visual = motif
			skill.color = Color(VISUAL_COLORS[motif])
			break
	skill["description"] = "%s · %.1fs cooldown\n%s" % [skill.label, skill.cooldown, EFFECTS[parts[2]].text]
	return skill
