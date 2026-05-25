ArcadeMatches = ArcadeMatches or {}

local _matches = {}
local _playerMatch = {}
local _nextMatchId = 1

local function notify(source, nType, message)
	TriggerClientEvent("Arcade:Client:Notify", source, nType, message)
end

local function notifyJoined(matchId, nType, message)
	local match = _matches[matchId]
	if not match then
		return
	end

	for src in pairs(match.queue) do
		notify(src, nType, message)
	end
	for src in pairs(match.players) do
		notify(src, nType, message)
	end
end

local function countTable(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

local function syncGlobalMatch(match)
	if not match then
		GlobalState["Arcade:Match"] = false
		TriggerClientEvent("Arcade:Client:SyncMatch", -1, false)
		return
	end

	local joinedCount = countTable(match.queue)
	if match.status == "active" then
		joinedCount = countTable(match.players)
	end

	GlobalState["Arcade:Match"] = {
		id = match.id,
		status = match.status,
		gamemode = match.gamemode,
		map = match.map,
		label = match.mapLabel,
		scores = match.scores,
		scoreLimit = match.scoreLimit,
		timeLimitSeconds = match.timeLimitSeconds,
		endsAt = match.endsAt,
		joinedCount = joinedCount,
		minPlayers = ARCADE_MATCH_DEFAULTS.minPlayers,
		maxPlayers = match.maxPlayers,
	}

	TriggerClientEvent("Arcade:Client:SyncMatch", -1, GlobalState["Arcade:Match"])
end

local function resolveMapId(mapId)
	if mapId == "random" then
		local keys = {}
		for id in pairs(ARCADE_MAPS) do
			keys[#keys + 1] = id
		end
		if #keys == 0 then
			return nil
		end
		return keys[math.random(#keys)]
	end

	if ARCADE_MAPS[mapId] then
		return mapId
	end

	return nil
end

local function getTeamSpawn(mapDef, team, index)
	local teamSpawns = mapDef.teams[team]
	if not teamSpawns or #teamSpawns == 0 then
		return ARCADE_RETURN
	end

	return teamSpawns[((index - 1) % #teamSpawns) + 1]
end

local function assignTeam(match)
	local counts = { red = 0, blue = 0 }

	for _, pdata in pairs(match.queue) do
		counts[pdata.team] = (counts[pdata.team] or 0) + 1
	end
	for _, pdata in pairs(match.players) do
		counts[pdata.team] = (counts[pdata.team] or 0) + 1
	end

	if counts.red <= counts.blue then
		return "red"
	end
	return "blue"
end

local function clearPlayerMatchState(source)
	_playerMatch[source] = nil
	Player(source).state:set("arcadeMatchId", nil, true)
	Player(source).state:set("arcadeTeam", nil, true)
	Player(source).state:set("arcadeEntered", false, true)
end

local function spawnPlayerInMatch(source, match, pdata, spawnIndex)
	local spawn = getTeamSpawn(match.mapDef, pdata.team, spawnIndex)

	ArcadeStripInventory(source)
	ArcadeGiveLoadout(source)
	exports["pulsar-core"]:AddPlayerToRoute(source, match.route, true)
	TriggerClientEvent("Arcade:Client:EnterMatch", source, {
		matchId = match.id,
		team = pdata.team,
		spawn = spawn,
		scores = match.scores,
		scoreLimit = match.scoreLimit,
		endsAt = match.endsAt,
	})
end

function ArcadeMatches.GetPlayerMatch(source)
	return _playerMatch[source]
end

function ArcadeMatches.GetMatch(matchId)
	return _matches[matchId]
end

function ArcadeMatches.CreateLobby(host, data)
	if GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].status ~= "ended" then
		return false, "A match is already active."
	end

	local gamemode = data and data.gamemode or "tdm"
	if not ARCADE_GAMEMODES[gamemode] then
		return false, "Invalid game mode."
	end

	local mapId = resolveMapId(data and data.map or "random")
	if not mapId then
		return false, "Invalid map."
	end

	local mapDef = ARCADE_MAPS[mapId]
	_nextMatchId = _nextMatchId + 1
	local matchId = ("arc_%s"):format(_nextMatchId)

	local match = {
		id = matchId,
		status = "lobby",
		gamemode = gamemode,
		map = mapId,
		mapLabel = mapDef.label,
		mapDef = mapDef,
		host = host,
		route = exports["pulsar-core"]:RequestRouteId(mapDef.routeName, false),
		scores = { red = 0, blue = 0 },
		scoreLimit = ARCADE_MATCH_DEFAULTS.scoreLimit,
		timeLimitSeconds = ARCADE_MATCH_DEFAULTS.timeLimitSeconds,
		maxPlayers = ARCADE_MATCH_DEFAULTS.maxPlayers,
		queue = {},
		players = {},
		endsAt = nil,
	}

	_matches[matchId] = match
	syncGlobalMatch(match)
	notify(host, "success", ("Match created: %s on %s. Players can Join Match at the terminal."):format(
		ARCADE_GAMEMODES[gamemode].label,
		mapDef.label
	))

	return true, match
end

function ArcadeMatches.JoinLobby(source)
	local matchId = GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].id
	if not matchId then
		return false, "No match has been created."
	end

	local match = _matches[matchId]
	if not match or match.status ~= "lobby" then
		return false, "This match is not accepting players."
	end

	if _playerMatch[source] then
		return false, "You have already joined this match."
	end

	if countTable(match.queue) >= match.maxPlayers then
		return false, "Match is full."
	end

	local char = exports["pulsar-characters"]:FetchCharacterSource(source)
	if not char then
		return false, "Character not loaded."
	end

	local team = assignTeam(match)
	match.queue[source] = {
		team = team,
		sid = char:GetData("SID"),
		kills = 0,
		deaths = 0,
	}
	_playerMatch[source] = matchId

	Player(source).state:set("arcadeMatchId", matchId, true)
	Player(source).state:set("arcadeTeam", team, true)
	Player(source).state:set("arcadeEntered", false, true)

	syncGlobalMatch(match)
	notify(source, "success", ("Joined match (%s team). Waiting for start..."):format(team))
	notifyJoined(matchId, "info", ("%s joined the match."):format(GetPlayerName(source)))
	return true, match
end

function ArcadeMatches.LeavePlayer(source, silent)
	local matchId = _playerMatch[source]
	if not matchId then
		return
	end

	local match = _matches[matchId]
	if not match then
		clearPlayerMatchState(source)
		return
	end

	if match.players[source] then
		ArcadeRestoreInventory(source)
		exports["pulsar-core"]:RoutePlayerToGlobalRoute(source)
		TriggerClientEvent("Arcade:Client:LeaveMatch", source, match.mapDef.exit or ARCADE_RETURN)
		match.players[source] = nil
	elseif match.queue[source] then
		match.queue[source] = nil
	end

	clearPlayerMatchState(source)

	if not silent then
		notify(source, "info", "You left the match.")
	end

	if countTable(match.players) <= 0 and countTable(match.queue) <= 0 and match.status ~= "lobby" then
		ArcadeMatches.EndMatch(matchId, "all_left", true)
	elseif match.status == "lobby" or match.status == "active" then
		syncGlobalMatch(match)
	end
end

function ArcadeMatches.StartMatch(source)
	local matchId = GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].id
	if not matchId then
		return false, "No match to start."
	end

	local match = _matches[matchId]
	if not match or match.status ~= "lobby" then
		return false, "Match cannot be started."
	end

	local joinedCount = countTable(match.queue)
	if joinedCount < ARCADE_MATCH_DEFAULTS.minPlayers then
		return false, ("Need at least %s players to have joined."):format(ARCADE_MATCH_DEFAULTS.minPlayers)
	end

	match.status = "active"
	match.startedAt = os.time()
	match.endsAt = os.time() + match.timeLimitSeconds

	local index = 0
	for src, pdata in pairs(match.queue) do
		index = index + 1
		match.players[src] = pdata
		match.queue[src] = nil
		Player(src).state:set("arcadeEntered", true, true)
		spawnPlayerInMatch(src, match, pdata, index)
	end

	syncGlobalMatch(match)

	notifyJoined(matchId, "success", "Match started! Fight!")
	SetTimeout(match.timeLimitSeconds * 1000, function()
		if _matches[matchId] and _matches[matchId].status == "active" then
			ArcadeMatches.EndMatch(matchId, "time", false)
		end
	end)

	return true, match
end

function ArcadeMatches.EndMatch(matchId, reason, silent)
	local match = _matches[matchId]
	if not match or match.status == "ended" then
		return
	end

	match.status = "ended"

	local winner
	if match.scores.red == match.scores.blue then
		winner = "draw"
	elseif match.scores.red > match.scores.blue then
		winner = "red"
	else
		winner = "blue"
	end

	for src, pdata in pairs(match.players) do
		ArcadeRestoreInventory(src)
		exports["pulsar-core"]:RoutePlayerToGlobalRoute(src)

		if pdata.kills and pdata.kills > 0 and type(_levelScale) == "table" then
			local xpGain = pdata.kills * 50
			exports["pulsar-core"]:LoggerInfo(
				"Arcade",
				("SID %s earned %s arcade XP (%s kills)"):format(pdata.sid, xpGain, pdata.kills),
				{ console = true }
			)
		end

		TriggerClientEvent("Arcade:Client:LeaveMatch", src, match.mapDef.exit or ARCADE_RETURN, {
			reason = reason,
			winner = winner,
			team = pdata.team,
			kills = pdata.kills,
			deaths = pdata.deaths,
		})
		clearPlayerMatchState(src)
	end

	for src in pairs(match.queue) do
		clearPlayerMatchState(src)
		if not silent then
			notify(src, "info", "The match has ended.")
		end
	end

	local message
	if reason == "time" then
		message = ("Time limit reached. %s wins! (%s - %s)"):format(
			winner == "draw" and "Draw" or (winner .. " team"),
			match.scores.red,
			match.scores.blue
		)
	elseif reason == "score" then
		message = ("%s team wins! (%s - %s)"):format(winner, match.scores.red, match.scores.blue)
	else
		message = "Match ended."
	end

	if not silent then
		notifyJoined(matchId, "info", message)
	end

	syncGlobalMatch(false)
	_matches[matchId] = nil
end

function ArcadeMatches.CancelLobby(source)
	local matchId = GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].id
	if not matchId then
		return false, "No match to cancel."
	end

	local match = _matches[matchId]
	if not match then
		GlobalState["Arcade:Match"] = false
		return true
	end

	if match.status == "active" then
		ArcadeMatches.EndMatch(matchId, "cancelled", false)
		return true
	end

	for src in pairs(match.queue) do
		clearPlayerMatchState(src)
		notify(src, "info", "Match cancelled.")
	end
	for src in pairs(match.players) do
		clearPlayerMatchState(src)
		notify(src, "info", "Match cancelled.")
	end

	_matches[matchId] = nil
	syncGlobalMatch(false)
	notify(source, "success", "Match cancelled.")
	return true
end

function ArcadeMatches.RegisterKill(victim, killer)
	if not killer or killer == victim then
		return
	end

	local matchId = _playerMatch[victim]
	if not matchId or matchId ~= _playerMatch[killer] then
		return
	end

	local match = _matches[matchId]
	if not match or match.status ~= "active" then
		return
	end

	local victimData = match.players[victim]
	local killerData = match.players[killer]
	if not victimData or not killerData then
		return
	end

	if victimData.team == killerData.team then
		return
	end

	killerData.kills = killerData.kills + 1
	victimData.deaths = victimData.deaths + 1
	match.scores[killerData.team] = match.scores[killerData.team] + 1
	syncGlobalMatch(match)

	for src in pairs(match.players) do
		TriggerClientEvent("Arcade:Client:ScoreUpdate", src, match.scores, match.scoreLimit)
	end

	if match.scores[killerData.team] >= match.scoreLimit then
		ArcadeMatches.EndMatch(matchId, "score", false)
	end
end

function ArcadeMatches.RespawnPlayer(source)
	local matchId = _playerMatch[source]
	local match = matchId and _matches[matchId]
	if not match or match.status ~= "active" then
		return false
	end

	local pdata = match.players[source]
	if not pdata then
		return false
	end

	local spawn = getTeamSpawn(match.mapDef, pdata.team, pdata.deaths + 1)
	ArcadeGiveLoadout(source)
	TriggerClientEvent("Arcade:Client:MatchRespawn", source, spawn)
	return true
end

function ArcadeMatches.ShutdownAll()
	for matchId in pairs(_matches) do
		ArcadeMatches.EndMatch(matchId, "restart", true)
	end
	GlobalState["Arcade:Match"] = false
end
