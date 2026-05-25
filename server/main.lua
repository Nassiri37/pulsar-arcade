local function isArcadeStaffOnDuty(source)
	local char = exports["pulsar-characters"]:FetchCharacterSource(source)
	if not char then
		return false
	end

	return Player(source).state.onDuty == ARCADE_JOB
end

local function registerCallbacks()
	exports["pulsar-core"]:RegisterServerCallback("Arcade:Open", function(source, _data, cb)
		if not isArcadeStaffOnDuty(source) then
			cb(false)
			return
		end

		GlobalState["Arcade:Open"] = true
		cb(true)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:Close", function(source, _data, cb)
		if not isArcadeStaffOnDuty(source) then
			cb(false)
			return
		end

		if GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].status == "active" then
			cb(false, "End the active match before closing the arcade.")
			return
		end

		if GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].status == "lobby" then
			ArcadeMatches.CancelLobby(source)
		end

		GlobalState["Arcade:Open"] = false
		cb(true)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:CreateMatch", function(source, data, cb)
		if not GlobalState["Arcade:Open"] then
			cb(false, "Arcade is closed.")
			return
		end

		if not isArcadeStaffOnDuty(source) then
			cb(false, "You must be on duty.")
			return
		end

		local ok, result = ArcadeMatches.CreateLobby(source, data)
		cb(ok, result)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:JoinMatch", function(source, _data, cb)
		if not GlobalState["Arcade:Open"] then
			cb(false, "Arcade is closed.")
			return
		end

		local ok, result = ArcadeMatches.JoinLobby(source)
		cb(ok, result)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:LeaveMatch", function(source, _data, cb)
		ArcadeMatches.LeavePlayer(source, false)
		cb(true)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:StartMatch", function(source, _data, cb)
		if not isArcadeStaffOnDuty(source) then
			cb(false, "You must be on duty.")
			return
		end

		local ok, result = ArcadeMatches.StartMatch(source)
		cb(ok, result)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:CancelMatch", function(source, _data, cb)
		if not isArcadeStaffOnDuty(source) then
			cb(false, "You must be on duty.")
			return
		end

		local ok, result = ArcadeMatches.CancelLobby(source)
		cb(ok, result)
	end)

	exports["pulsar-core"]:RegisterServerCallback("Arcade:EndMatch", function(source, _data, cb)
		if not isArcadeStaffOnDuty(source) then
			cb(false, "You must be on duty.")
			return
		end

		local matchId = GlobalState["Arcade:Match"] and GlobalState["Arcade:Match"].id
		if matchId then
			ArcadeMatches.EndMatch(matchId, "staff", false)
		end
		cb(true)
	end)
end

RegisterNetEvent("Arcade:Server:PlayerDied", function(killerServerId)
	local victim = source
	local killer = tonumber(killerServerId)
	if killer and killer > 0 then
		ArcadeMatches.RegisterKill(victim, killer)
	end

	SetTimeout(ARCADE_MATCH_DEFAULTS.respawnDelayMs, function()
		if GetPlayerPing(victim) > 0 then
			ArcadeMatches.RespawnPlayer(victim)
		end
	end)
end)

RegisterNetEvent("Arcade:Server:RequestRespawn", function()
	ArcadeMatches.RespawnPlayer(source)
end)

AddEventHandler("playerDropped", function()
	local src = source
	if ArcadeMatches.GetPlayerMatch(src) then
		ArcadeMatches.LeavePlayer(src, true)
	end
end)

AddEventHandler("onResourceStart", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	Wait(500)
	registerCallbacks()

	if GlobalState["Arcade:Open"] == nil then
		GlobalState["Arcade:Open"] = false
	end

	if GlobalState["Arcade:Match"] == nil then
		GlobalState["Arcade:Match"] = false
	end
end)

AddEventHandler("onResourceStop", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	ArcadeMatches.ShutdownAll()
end)
