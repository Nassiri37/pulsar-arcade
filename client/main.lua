local _gamemodes = {
	{ value = "tdm", label = "Team Deathmatch" },
}

local _maps = {
	{ value = "random", label = "Random" },
	{ value = "legionsquare", label = "Legion Square" },
}

local function notify(type, message)
	exports["pulsar-hud"]:Notification(type, message)
end

local _syncedMatch = nil

local function getActiveMatch()
	local match = GlobalState["Arcade:Match"]
	if match and match ~= false and type(match) == "table" then
		return match
	end
	return _syncedMatch
end

local function isArcadeOpen()
	return GlobalState["Arcade:Open"] == true
end

local function hasJoinedMatchQueue()
	local matchId = LocalPlayer.state.arcadeMatchId
	return matchId ~= nil and matchId ~= false and matchId ~= ""
end

local function canJoinMatch()
	if not isArcadeOpen() then
		return false
	end

	local match = getActiveMatch()
	if not match or match.status ~= "lobby" then
		return false
	end

	return not hasJoinedMatchQueue()
end

local function canLeaveMatchQueue()
	local match = getActiveMatch()
	return hasJoinedMatchQueue()
		and match
		and match.status == "lobby"
		and not exports["pulsar-arcade"]:InMatch()
end

RegisterNetEvent("Arcade:Client:SyncMatch", function(match)
	if match and type(match) == "table" then
		_syncedMatch = match
	else
		_syncedMatch = nil
	end
end)

AddStateBagChangeHandler("Arcade:Match", "global", function(_, _, value)
	if value and type(value) == "table" then
		_syncedMatch = value
	else
		_syncedMatch = nil
	end
end)

local function buildSelectOptions(entries)
	local options = {}
	for _, entry in ipairs(entries) do
		options[#options + 1] = {
			label = entry.label,
			value = entry.value,
		}
	end
	return options
end

local function showCreateLobbyPicker()
	exports["pulsar-hud"]:InputShow(
		"Create Match Lobby",
		"Select game mode and map",
		{
			{
				id = "gamemode",
				type = "select",
				select = buildSelectOptions(_gamemodes),
				options = { label = "Game Mode" },
			},
			{
				id = "map",
				type = "select",
				select = buildSelectOptions(_maps),
				options = { label = "Map" },
			},
		},
		"Arcade:Client:PickLobby",
		{}
	)
end

local function setupJoinZone()
	local zone = ARCADE_JOIN_ZONE

	exports.ox_target:removeZone(zone.id)
	exports.ox_target:addBoxZone({
		id = zone.id,
		coords = zone.coords,
		size = zone.size,
		rotation = zone.rotation,
		debug = false,
		minZ = zone.minZ,
		maxZ = zone.maxZ,
		options = {
			{
				icon = "fas fa-gamepad",
				label = "Join Match",
				distance = 3.0,
				onSelect = function()
					TriggerEvent("Arcade:Client:JoinMatch")
				end,
				canInteract = canJoinMatch,
			},
			{
				icon = "fas fa-door-open",
				label = "Leave Match",
				distance = 3.0,
				onSelect = function()
					TriggerEvent("Arcade:Client:LeaveMatch")
				end,
				canInteract = canLeaveMatchQueue,
			},
			{
				icon = "fas fa-right-from-bracket",
				label = "Leave Match",
				distance = 3.0,
				onSelect = function()
					TriggerEvent("Arcade:Client:LeaveMatch")
				end,
				canInteract = function()
					return exports["pulsar-arcade"]:InMatch()
				end,
			},
		},
	})
end

local function setupArcadePed()
	local ped = ARCADE_PED

	exports["pulsar-pedinteraction"]:Remove(ped.id)
	exports["pulsar-pedinteraction"]:Add(
		ped.id,
		ped.model,
		ped.coords,
		ped.heading,
		ped.range,
		{
			{
				icon = "clipboard-check",
				text = "Clock In",
				event = "Arcade:Client:ClockIn",
				data = { job = ARCADE_JOB },
				groups = { ARCADE_JOB },
				reqOffDuty = true,
			},
			{
				icon = "clipboard",
				text = "Clock Out",
				event = "Arcade:Client:ClockOut",
				data = { job = ARCADE_JOB },
				groups = { ARCADE_JOB },
				reqDuty = true,
			},
			{
				icon = "heart-pulse",
				text = "Open Arcade",
				event = "Arcade:Client:Open",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					return not GlobalState["Arcade:Open"]
				end,
			},
			{
				icon = "heart-pulse",
				text = "Close Arcade",
				event = "Arcade:Client:Close",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					return GlobalState["Arcade:Open"] == true
				end,
			},
			{
				icon = "gamepad",
				text = "Create Match Lobby",
				event = "Arcade:Client:CreateNew",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					return GlobalState["Arcade:Open"] and not getActiveMatch()
				end,
			},
			{
				icon = "gamepad",
				text = "Join Match",
				event = "Arcade:Client:JoinMatch",
				isEnabled = canJoinMatch,
			},
			{
				icon = "door-open",
				text = "Leave Match",
				event = "Arcade:Client:LeaveMatch",
				isEnabled = canLeaveMatchQueue,
			},
			{
				icon = "play",
				text = "Start Match",
				event = "Arcade:Client:StartMatch",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					local match = getActiveMatch()
					if not match or match.status ~= "lobby" then
						return false
					end
					return (match.joinedCount or 0) >= ARCADE_MATCH_DEFAULTS.minPlayers
				end,
			},
			{
				icon = "flag-checkered",
				text = "End Match",
				event = "Arcade:Client:EndMatch",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					local match = getActiveMatch()
					return match and match.status == "active"
				end,
			},
			{
				icon = "ban",
				text = "Cancel Lobby",
				event = "Arcade:Client:CancelMatch",
				groups = { ARCADE_JOB },
				reqDuty = true,
				isEnabled = function()
					local match = getActiveMatch()
					return match and match.status == "lobby"
				end,
			},
		},
		ped.icon,
		ped.scenario
	)
end

local function setupArcade()
	setupArcadePed()
	setupJoinZone()
end

AddEventHandler("onClientResourceStart", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	Wait(1000)
	setupArcade()
end)

RegisterNetEvent("Characters:Client:Spawn", function()
	setupArcade()
end)

AddEventHandler("Arcade:Client:ClockIn", function(data)
	if data and data.job then
		exports["pulsar-jobs"]:DutyOn(data.job)
	end
end)

AddEventHandler("Arcade:Client:ClockOut", function(data)
	if data and data.job then
		exports["pulsar-jobs"]:DutyOff(data.job)
	end
end)

AddEventHandler("Arcade:Client:Open", function()
	exports["pulsar-core"]:ServerCallback("Arcade:Open", {}, function(success, err)
		if success then
			notify("success", "Arcade is now open.")
		else
			notify("error", err or "You must be on duty to open the arcade.")
		end
	end)
end)

AddEventHandler("Arcade:Client:Close", function()
	exports["pulsar-core"]:ServerCallback("Arcade:Close", {}, function(success, err)
		if success then
			notify("success", "Arcade is now closed.")
		else
			notify("error", err or "You must be on duty to close the arcade.")
		end
	end)
end)

AddEventHandler("Arcade:Client:CreateNew", function()
	showCreateLobbyPicker()
end)

AddEventHandler("Arcade:Client:PickLobby", function(values)
	if not values or not values.gamemode then
		notify("error", "Select a game mode.")
		return
	end

	if not values.map then
		notify("error", "Select a map.")
		return
	end

	local payload = {
		gamemode = values.gamemode,
		map = values.map,
	}

	exports["pulsar-core"]:ServerCallback("Arcade:CreateMatch", payload, function(success, err)
		if success then
			notify("success", "Match created. Use Join Match on the arcade NPC or terminal.")
		else
			notify("error", type(err) == "string" and err or "Unable to create lobby.")
		end
	end)
end)

AddEventHandler("Arcade:Client:JoinMatch", function()
	exports["pulsar-core"]:ServerCallback("Arcade:JoinMatch", {}, function(success, err)
		if success then
			notify("success", "Joined the match. Waiting for start...")
		else
			notify("error", type(err) == "string" and err or "Unable to join match.")
		end
	end)
end)

AddEventHandler("Arcade:Client:LeaveMatch", function()
	exports["pulsar-core"]:ServerCallback("Arcade:LeaveMatch", {}, function(success)
		if success then
			notify("info", "Left the match.")
		end
	end)
end)

AddEventHandler("Arcade:Client:StartMatch", function()
	exports["pulsar-core"]:ServerCallback("Arcade:StartMatch", {}, function(success, err)
		if success then
			notify("success", "Match started.")
		else
			notify("error", type(err) == "string" and err or "Unable to start match.")
		end
	end)
end)

AddEventHandler("Arcade:Client:EndMatch", function()
	exports["pulsar-core"]:ServerCallback("Arcade:EndMatch", {}, function(success)
		if success then
			notify("info", "Match ended.")
		end
	end)
end)

AddEventHandler("Arcade:Client:CancelMatch", function()
	exports["pulsar-core"]:ServerCallback("Arcade:CancelMatch", {}, function(success, err)
		if success then
			notify("info", "Lobby cancelled.")
		else
			notify("error", type(err) == "string" and err or "Unable to cancel.")
		end
	end)
end)


local _registeredGamemodes = {}

exports("RegisterGamemode", function(id, label)
	if type(id) ~= "string" or type(label) ~= "string" then
		return false
	end

	_registeredGamemodes[id] = label
	_gamemodes[#_gamemodes + 1] = { value = id, label = label }
	return true
end)

exports("GetGamemodes", function()
	return _gamemodes
end)
