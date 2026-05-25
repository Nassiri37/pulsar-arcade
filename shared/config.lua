ARCADE_JOB = "avast_arcade"

ARCADE_PED = {
	id = "ArcadeMaster",
	model = `cs_jimmydisanto`,
	coords = vector3(-1658.916, -1062.421, 11.160),
	heading = 228.868,
	range = 25.0,
	icon = "joystick",
	scenario = "WORLD_HUMAN_STAND_IMPATIENT",
}

ARCADE_RETURN = vector4(-1658.885, -1064.898, 12.160, 238.646)

ARCADE_JOIN_ZONE = {
	id = "arcade_join_terminal",
	coords = vector3(-1656.5, -1063.2, 12.16),
	size = vector3(2.0, 2.0, 2.5),
	rotation = 320,
	minZ = 11.16,
	maxZ = 13.66,
}

ARCADE_MATCH_DEFAULTS = {
	scoreLimit = 25,
	timeLimitSeconds = 600,
	minPlayers = 2,
	maxPlayers = 16,
	respawnDelayMs = 2500,
}

---@type table<string, { label: string, routeName: string, return?: vector4, teams: table<string, vector4[]> }>
ARCADE_MAPS = {
	legionsquare = {
		label = "Legion Square",
		routeName = "arcade_legion",
		exit = ARCADE_RETURN,
		teams = {
			red = {
				vector4(195.12, -933.41, 30.69, 144.0),
				vector4(189.55, -936.88, 30.69, 144.0),
				vector4(201.80, -929.70, 30.69, 144.0),
			},
			blue = {
				vector4(239.88, -880.15, 30.49, 324.0),
				vector4(234.10, -884.02, 30.49, 324.0),
				vector4(245.60, -876.40, 30.49, 324.0),
			},
		},
	},
}

ARCADE_GAMEMODES = {
	tdm = {
		label = "Team Deathmatch",
		teams = { "red", "blue" },
	},
}

ARCADE_LOADOUT = {
	{ name = "WEAPON_PISTOL", count = 1, metadata = { ammo = 120, clip = 12, arcadeLoadout = true } },
}
