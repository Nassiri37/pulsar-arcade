local function isArcadeStaffOnDuty(source)
	local char = exports["pulsar-characters"]:FetchCharacterSource(source)
	if not char then
		return false
	end

	return Player(source).state.onDuty == ARCADE_JOB
end

local function registerCharacterInventoryHooks()
	exports["pulsar-core"]:MiddlewareAdd("Characters:Spawning", function(source)
		local char = exports["pulsar-characters"]:FetchCharacterSource(source)
		if not char then
			return true
		end

		local sid = tostring(char:GetData("SID"))
		local strippedSid = Player(source).state.arcadeInvStrippedSid
		if strippedSid and tostring(strippedSid) ~= sid then
			Player(source).state:set("arcadeInvStrippedSid", nil, true)
		end

		SetTimeout(2500, function()
			if GetPlayerPing(source) <= 0 then
				return
			end

			local currentChar = exports["pulsar-characters"]:FetchCharacterSource(source)
			if not currentChar then
				return
			end

			if Player(source).state.arcadeInvStrippedSid then
				return
			end

			if ArcadeMatches.GetPlayerMatch(source) then
				return
			end

			-- Recover inventory if a confiscation stash exists (no-op if already restored).
			exports["pulsar-arcade"]:RestoreInventory(source)
		end)

		return true
	end, 20)
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
		local hadState = ArcadeMatches.GetPlayerMatch(source) or Player(source).state.arcadeMatchId
		ArcadeMatches.LeavePlayer(source, false)
		if hadState then
			cb(true)
		else
			cb(false, "You are not in a match.")
		end
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

	-- Best-effort restore if they disconnect while stripped (before character unloads).
	if Player(src).state.arcadeInvStrippedSid then
		exports["pulsar-arcade"]:RestoreInventory(src)
	end
end)

AddEventHandler("onResourceStart", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	Wait(500)
	registerCallbacks()
	registerCharacterInventoryHooks()

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
