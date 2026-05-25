local _inMatch = false
local _matchTeam = nil
local _scoreActionId = "arcade_match_score"

local function formatScoreLine(scores, limit)
	return ("RED %s  |  BLUE %s  (first to %s)"):format(scores.red or 0, scores.blue or 0, limit or "?")
end

local function updateScoreHud(scores, limit)
	exports["pulsar-hud"]:ActionHide(_scoreActionId)
	exports["pulsar-hud"]:ActionShow(_scoreActionId, formatScoreLine(scores, limit), 0)
end

local function revivePlayer()
	pcall(function()
		exports["pulsar-damage"]:Revive(true)
	end)

	local ped = PlayerPedId()
	SetEntityHealth(ped, GetEntityMaxHealth(ped))
	ClearPedBloodDamage(ped)
end

RegisterNetEvent("Arcade:Client:EnterMatch", function(data)
	_inMatch = true
	_matchTeam = data.team

	DoScreenFadeOut(400)
	while not IsScreenFadedOut() do
		Wait(10)
	end

	local spawn = data.spawn
	SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z, false, false, false, false)
	SetEntityHeading(PlayerPedId(), spawn.w or 0.0)

	Wait(300)
	DoScreenFadeIn(400)

	updateScoreHud(data.scores or { red = 0, blue = 0 }, data.scoreLimit)
	exports["pulsar-hud"]:Notification("success", ("Match started — you are on team %s"):format(data.team))
end)

RegisterNetEvent("Arcade:Client:LeaveMatch", function(exitCoords, summary)
	local wasInMatch = _inMatch
	_inMatch = false
	_matchTeam = nil
	exports["pulsar-hud"]:ActionHide(_scoreActionId)

	if wasInMatch or LocalPlayer.state.isDead then
		revivePlayer()
	end

	if summary then
		local result
		if summary.winner == "draw" then
			result = "Draw"
		elseif summary.winner == summary.team then
			result = "Victory"
		else
			result = "Defeat"
		end

		exports["pulsar-hud"]:Notification(
			"info",
			("%s — K/D %s/%s"):format(result, summary.kills or 0, summary.deaths or 0)
		)
	end

	if exitCoords then
		DoScreenFadeOut(400)
		while not IsScreenFadedOut() do
			Wait(10)
		end

		revivePlayer()

		local ped = PlayerPedId()
		SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
		SetEntityHeading(ped, exitCoords.w or 0.0)
		SetEntityHealth(ped, GetEntityMaxHealth(ped))

		Wait(300)
		DoScreenFadeIn(400)
	end
end)

RegisterNetEvent("Arcade:Client:MatchRespawn", function(spawn)
	if not _inMatch or not spawn then
		return
	end

	revivePlayer()

	Wait(500)

	local ped = PlayerPedId()
	SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
	SetEntityHeading(ped, spawn.w or 0.0)
	SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

RegisterNetEvent("Arcade:Client:ScoreUpdate", function(scores, limit)
	if not _inMatch then
		return
	end

	updateScoreHud(scores, limit)
end)

RegisterNetEvent("Arcade:Client:Notify", function(nType, message)
	exports["pulsar-hud"]:Notification(nType, message)
end)

CreateThread(function()
	local wasDead = false
	while true do
		Wait(400)

		if not _inMatch then
			wasDead = false
		else
			local dead = LocalPlayer.state.isDead
			if dead and not wasDead then
				wasDead = true
				local killer = GetPedSourceOfDeath(PlayerPedId())
				local killerPlayer = -1
				if killer and killer ~= 0 and IsEntityAPed(killer) and IsPedAPlayer(killer) then
					killerPlayer = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer))
				end
				TriggerServerEvent("Arcade:Server:PlayerDied", killerPlayer)
			elseif not dead then
				wasDead = false
			end
		end
	end
end)

exports("InMatch", function()
	return _inMatch
end)

exports("GetTeam", function()
	return _matchTeam
end)
